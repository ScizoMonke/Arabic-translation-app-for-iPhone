import AVFoundation
import Foundation
import WhisperKit

/// What the microphone indicator shows.
enum MicState: Sendable {
    case off
    case listening   // mic open, nobody talking
    case hearing     // speech in progress, an utterance is being collected
    case holding     // he is holding the bottom half: audio goes to his English only
}

/// One utterance for the top half, with the moment the cutter ended it (the
/// "utterance-end" of the TIME line; speech itself stopped about 0.8 s earlier,
/// which is the cutter's quiet hangover).
struct Utterance: Sendable {
    let samples: [Float]
    let endedAt: Date
}

/// Splits a continuous 16 kHz mono stream into utterances with an energy gate.
/// Runs only on the audio tap thread.
struct Segmenter {
    private let sampleRate = 16_000
    private var preRollSamples: Int { sampleRate * 3 / 10 }      // 0.3 s kept before speech starts
    private var hangoverSamples: Int { sampleRate * 8 / 10 }     // 0.8 s of quiet ends an utterance
    private var maxSamples: Int { sampleRate * 25 }              // Whisper's window is 30 s
    private var minSpeechSamples: Int { sampleRate * 35 / 100 }  // shorter blips are coughs and clicks

    private var noiseFloor: Float = 0.003
    private var inSpeech = false
    private var current: [Float] = []
    private var preRoll: [Float] = []
    private var quietRun = 0
    private var speechRun = 0

    /// Forgets any utterance in progress and the pre-roll. Used at both ends of a
    /// hold so none of his speech reaches the top half. The noise floor is kept:
    /// it describes the room, not the speaker.
    mutating func discardUtterance() {
        inSpeech = false
        current.removeAll(keepingCapacity: true)
        preRoll.removeAll(keepingCapacity: true)
        quietRun = 0
        speechRun = 0
    }

    /// Feeds one chunk; returns a finished utterance when one just ended, and
    /// whether speech is in progress after this chunk.
    mutating func push(_ chunk: [Float]) -> (utterance: [Float]?, speaking: Bool) {
        guard !chunk.isEmpty else { return (nil, inSpeech) }
        var sumSquares: Float = 0
        for s in chunk { sumSquares += s * s }
        let rms = (sumSquares / Float(chunk.count)).squareRoot()
        // Speech must clear both a multiple of the room's own noise and an absolute
        // floor, so a quiet room does not turn breathing into utterances.
        let isLoud = rms > max(noiseFloor * 3.0, 0.008)

        if !inSpeech {
            // The noise floor follows the room only while nobody is talking.
            noiseFloor = max(0.0005, noiseFloor * 0.95 + rms * 0.05)
            preRoll.append(contentsOf: chunk)
            if preRoll.count > preRollSamples {
                preRoll.removeFirst(preRoll.count - preRollSamples)
            }
            guard isLoud else { return (nil, false) }
            inSpeech = true
            current = preRoll
            preRoll.removeAll(keepingCapacity: true)
            quietRun = 0
            speechRun = chunk.count
            return (nil, true)
        }

        current.append(contentsOf: chunk)
        if isLoud {
            quietRun = 0
            speechRun += chunk.count
        } else {
            quietRun += chunk.count
        }

        if quietRun >= hangoverSamples || current.count >= maxSamples {
            let finished = current
            let hadEnoughSpeech = speechRun >= minSpeechSamples
            inSpeech = false
            current.removeAll(keepingCapacity: true)
            quietRun = 0
            speechRun = 0
            return (hadEnoughSpeech ? finished : nil, false)
        }
        return (nil, true)
    }
}

/// Keeps the microphone open while the app is in the foreground and delivers
/// utterances (16 kHz mono Float) for the top half through `utterances`.
///
/// D34 hold routing. While he holds the bottom half, every tap buffer goes, in
/// the input's native format, to the hold sink (his English recognizer) and
/// NOTHING is fed to the utterance cutter; the cutter's utterance in progress is
/// discarded when the hold starts and again when it ends, and the cutter stays
/// deaf for `releaseMute` after release so the tail of his voice still in the
/// pipe cannot open a top-half utterance. The hold state lives under `holdLock`
/// because the main thread sets it and the audio tap thread reads it. It
/// survives an engine restart (headset, phone call), so a restart mid-hold can
/// never send his voice to the top half.
final class MicCapture {
    let utterances: AsyncStream<Utterance>
    private let continuation: AsyncStream<Utterance>.Continuation
    private let engine = AVAudioEngine()
    /// Tap thread only (and `open`, before the tap exists).
    private var segmenter = Segmenter()
    private var lastSpeaking = false

    /// After release, how long the cutter ignores the microphone.
    static let releaseMute: TimeInterval = 0.5
    private let holdLock = NSLock()
    /// Guarded by holdLock. Non-nil exactly while he holds.
    private var holdSink: (@Sendable (AVAudioPCMBuffer) -> Void)?
    /// Guarded by holdLock. Set at both ends of a hold; the tap thread then
    /// discards the cutter's utterance in progress before using the buffer.
    private var discardPending = false
    /// Guarded by holdLock. The cutter ignores audio until this moment.
    private var mutedUntil: Date?
    /// The owner wants the mic open (app in foreground, model ready).
    private var wanted = false
    /// The engine is actually running right now.
    private var running = false
    private var observers: [NSObjectProtocol] = []

    /// Indicator changes. A stream rather than a callback so the consumer reads it
    /// on its own actor and nothing here has to know about the main thread.
    let states: AsyncStream<MicState>
    private let stateContinuation: AsyncStream<MicState>.Continuation

    init() {
        let (stream, continuation) = AsyncStream.makeStream(of: Utterance.self, bufferingPolicy: .unbounded)
        self.utterances = stream
        self.continuation = continuation
        let (stateStream, stateContinuation) = AsyncStream.makeStream(of: MicState.self, bufferingPolicy: .bufferingNewest(8))
        self.states = stateStream
        self.stateContinuation = stateContinuation
        observeInterruptions()
    }

    deinit {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        continuation.finish()
        stateContinuation.finish()
    }

    func start() throws {
        wanted = true
        try open()
    }

    func stop() {
        wanted = false
        close()
    }

    /// Touch down on the bottom half. From the next tap buffer on, audio goes
    /// to `sink` only (called on the audio tap thread) and the top half hears
    /// nothing.
    func beginHold(sink: @escaping @Sendable (AVAudioPCMBuffer) -> Void) {
        holdLock.lock()
        holdSink = sink
        discardPending = true
        mutedUntil = nil
        holdLock.unlock()
        report(.holding)
    }

    /// Release. The sink gets no more buffers; the top half resumes after
    /// `releaseMute` with a clean cutter.
    func endHold() {
        holdLock.lock()
        holdSink = nil
        discardPending = true
        mutedUntil = Date().addingTimeInterval(Self.releaseMute)
        holdLock.unlock()
        report(running ? .listening : .off)
    }

    private func open() throws {
        guard !running else { return }
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .default, options: [])
        try session.setActive(true)

        let input = engine.inputNode
        let inputFormat = input.outputFormat(forBus: 0)
        guard inputFormat.sampleRate > 0,
              let whisperFormat = AVAudioFormat(
                  commonFormat: .pcmFormatFloat32,
                  sampleRate: Double(WhisperKit.sampleRate),
                  channels: 1,
                  interleaved: false
              ),
              let converter = AVAudioConverter(from: inputFormat, to: whisperFormat)
        else {
            throw NSError(domain: "MicCapture", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Microphone format unavailable"])
        }

        segmenter = Segmenter()
        input.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
            guard let self else { return }
            // His hold first: a buffer that goes to his English never reaches
            // the cutter, not even resampled.
            guard self.routeOutsideCutter(buffer) == false else { return }
            let converted: AVAudioPCMBuffer
            do {
                converted = try AudioProcessor.resampleBuffer(buffer, with: converter)
            } catch {
                print("MicCapture resample failed: \(error)")
                return
            }
            self.consume(AudioProcessor.convertBufferToArray(buffer: converted))
        }
        engine.prepare()
        do {
            try engine.start()
        } catch {
            // A tap left behind would make the next installTap trap.
            input.removeTap(onBus: 0)
            throw error
        }
        running = true
        holdLock.lock()
        let holding = holdSink != nil
        holdLock.unlock()
        report(holding ? .holding : .listening)
    }

    private func close() {
        guard running else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        running = false
        lastSpeaking = false
        // The audio session is left active on purpose: deactivating it can itself
        // fire a configuration change, which would restart the engine in a loop.
        report(.off)
    }

    /// Audio tap thread. True when the buffer must not reach the cutter: it went
    /// to his hold, or the cutter is muted just after a release.
    private func routeOutsideCutter(_ buffer: AVAudioPCMBuffer) -> Bool {
        holdLock.lock()
        let sink = holdSink
        let discard = discardPending
        discardPending = false
        let muted = mutedUntil.map { Date() < $0 } ?? false
        holdLock.unlock()

        if discard {
            segmenter.discardUtterance()
            lastSpeaking = false
        }
        if let sink {
            sink(buffer)
            return true
        }
        return muted
    }

    /// Audio tap thread. Never reached during a hold, so the indicator below
    /// cannot overwrite `.holding`.
    private func consume(_ samples: [Float]) {
        let (finished, speaking) = segmenter.push(samples)
        if let finished {
            continuation.yield(Utterance(samples: finished, endedAt: Date()))
        }
        if speaking != lastSpeaking {
            lastSpeaking = speaking
            report(speaking ? .hearing : .listening)
        }
    }

    private func report(_ state: MicState) {
        stateContinuation.yield(state)
    }

    /// A phone call or Siri stops the engine; a headset plugged in changes the
    /// input format. Either way, rebuild the tap so listening resumes by itself.
    private func observeInterruptions() {
        let center = NotificationCenter.default
        observers.append(center.addObserver(
            forName: AVAudioSession.interruptionNotification, object: nil, queue: .main
        ) { [weak self] note in
            guard let self,
                  let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: raw) else { return }
            if type == .began {
                self.close()
            } else if self.wanted {
                self.restart()
            }
        })
        observers.append(center.addObserver(
            forName: .AVAudioEngineConfigurationChange, object: engine, queue: .main
        ) { [weak self] _ in
            // Only a running engine needs rebuilding; ignore changes while stopped.
            guard let self, self.running else { return }
            self.restart()
        })
    }

    private func restart() {
        close()
        do {
            try open()
        } catch {
            print("MicCapture restart failed: \(error)")
        }
    }
}
