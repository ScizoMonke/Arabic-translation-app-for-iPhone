import AVFoundation
import Foundation
import WhisperKit

/// What the microphone indicator shows.
enum MicState: Sendable {
    case off
    case listening   // mic open, nobody talking
    case hearing     // speech in progress, an utterance is being collected
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
/// utterances (16 kHz mono Float) through `utterances`. Never needs a button.
final class MicCapture {
    let utterances: AsyncStream<[Float]>
    private let continuation: AsyncStream<[Float]>.Continuation
    private let engine = AVAudioEngine()
    private var segmenter = Segmenter()
    private var lastSpeaking = false
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
        let (stream, continuation) = AsyncStream.makeStream(of: [Float].self, bufferingPolicy: .unbounded)
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
        report(.listening)
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

    /// Audio tap thread.
    private func consume(_ samples: [Float]) {
        let (utterance, speaking) = segmenter.push(samples)
        if let utterance {
            continuation.yield(utterance)
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
