import AVFoundation
import Foundation
import WhisperKit

/// What the microphone indicator shows.
enum MicState: Sendable {
    case off
    case listening   // mic open, nobody talking
    case hearing     // speech in progress
    case holding     // he is holding the bottom half: audio goes to his English only
}

/// An energy gate over a continuous 16 kHz mono stream: says when speech
/// starts, which audio belongs to it, and when it ends. It keeps no utterance
/// itself; the audio goes to the LiveWindow. Runs only on the audio tap thread.
struct Segmenter {
    struct Step {
        /// Speech began with this chunk; `audio` is then the pre-roll, which
        /// already ends with this chunk.
        var started = false
        /// Audio that belongs to the utterance in progress (empty when quiet).
        var audio: [Float] = []
        /// The utterance ended with this chunk (after `audio` is added).
        var ended = false
        /// At the end: enough loud audio to be speech, not a cough or a click.
        var enoughSpeech = false
        /// Loud samples in the utterance so far.
        var loudSamples = 0
        var speaking = false
    }

    static let sampleRate = 16_000
    private var preRollSamples: Int { Self.sampleRate * 3 / 10 }      // 0.3 s kept before speech starts
    private var hangoverSamples: Int { Self.sampleRate * 8 / 10 }     // 0.8 s of quiet ends an utterance
    static let minSpeechSamples = sampleRate * 35 / 100               // shorter blips are coughs and clicks

    private var noiseFloor: Float = 0.003
    private var inSpeech = false
    private var preRoll: [Float] = []
    private var quietRun = 0
    private var speechRun = 0

    /// Forgets the utterance in progress and the pre-roll. Used at both ends of
    /// a hold so none of his speech reaches the top half. The noise floor is
    /// kept: it describes the room, not the speaker.
    mutating func discardUtterance() {
        inSpeech = false
        preRoll.removeAll(keepingCapacity: true)
        quietRun = 0
        speechRun = 0
    }

    mutating func push(_ chunk: [Float]) -> Step {
        guard !chunk.isEmpty else { return Step(speaking: inSpeech) }
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
            guard isLoud else { return Step() }
            inSpeech = true
            let audio = preRoll
            preRoll.removeAll(keepingCapacity: true)
            quietRun = 0
            speechRun = chunk.count
            return Step(started: true, audio: audio, loudSamples: speechRun, speaking: true)
        }

        if isLoud {
            quietRun = 0
            speechRun += chunk.count
        } else {
            quietRun += chunk.count
        }
        var step = Step(audio: chunk, loudSamples: speechRun, speaking: true)
        if quietRun >= hangoverSamples {
            step.ended = true
            step.enoughSpeech = speechRun >= Self.minSpeechSamples
            step.speaking = false
            inSpeech = false
            quietRun = 0
            speechRun = 0
        }
        return step
    }
}

/// D43: the top half's audio since the last settle point, shared between the
/// audio tap thread (which appends) and the live loop in AppModel (which
/// snapshots, decodes, and advances the start past settled words). Everything
/// is under one lock; the tap thread never waits on a decode, only on this
/// lock for a copy.
///
/// The window holds one or more utterances back to back (quiet between them
/// is not kept). Only the last one can still be open. A snapshot covers the
/// oldest utterance: to its end when closed (the loop then settles all of it),
/// or to the newest sample when open.
///
/// Generation: any change other than appending at the end or advancing the
/// start (a hold edge, a blip removed, the safety cap) bumps it, and a decode
/// started on an older generation is thrown away without settling anything.
/// That is how a hold seals his voice from the top half (D34): his audio is
/// never appended (suspended), and nothing decoded before the hold can be
/// settled into a window that was emptied under it.
final class LiveWindow: @unchecked Sendable {
    struct Snapshot: Sendable {
        let generation: Int
        let samples: [Float]
        /// The utterance ended inside this snapshot, at its last sample.
        let closed: Bool
        /// Wall clock of the utterance's first sample (pre-roll included).
        let speechStartedAt: Date
        let loudSamples: Int
        /// Samples appended in this generation so far, to pace decodes.
        let appended: Int
    }

    private struct Mark {
        var start: Int
        var end: Int?
        let startedAt: Date
        var loud: Int
    }

    /// If the loop stops consuming (a model failed), the oldest audio is let go
    /// past this length instead of growing without bound.
    private static let capSamples = Segmenter.sampleRate * 90

    private let lock = NSLock()
    private var samples: [Float] = []
    private var marks: [Mark] = []
    private var generation = 0
    private var appended = 0
    private var suspended = false

    // MARK: Audio tap thread

    func speechStarted(_ audio: [Float], loud: Int, at date: Date) {
        lock.lock(); defer { lock.unlock() }
        guard !suspended else { return }
        // Only the last utterance may be open; one left open by an engine
        // restart is closed here, so its audio is still settled.
        if let last = marks.indices.last, marks[last].end == nil {
            marks[last].end = samples.count
        }
        marks.append(Mark(start: samples.count, end: nil, startedAt: date, loud: loud))
        appendLocked(audio)
    }

    func speechContinued(_ audio: [Float], loud: Int) {
        lock.lock(); defer { lock.unlock() }
        guard !suspended, let last = marks.indices.last, marks[last].end == nil else { return }
        marks[last].loud = loud
        appendLocked(audio)
    }

    func speechEnded(enoughSpeech: Bool) {
        lock.lock(); defer { lock.unlock() }
        guard !suspended, let last = marks.indices.last, marks[last].end == nil else { return }
        if enoughSpeech {
            marks[last].end = samples.count
        } else {
            dropLastLocked()
        }
    }

    private func appendLocked(_ audio: [Float]) {
        samples.append(contentsOf: audio)
        appended += audio.count
        if samples.count > Self.capSamples {
            shiftLocked(by: samples.count - Self.capSamples)
            generation += 1
        }
    }

    /// A cough or a click: its audio leaves the window before any decode could
    /// settle it (the loop decodes an open utterance only after
    /// minSpeechSamples of loud audio, so none is running on it).
    private func dropLastLocked() {
        guard let last = marks.last else { return }
        samples.removeSubrange(last.start...)
        marks.removeLast()
        generation += 1
    }

    // MARK: Owner

    /// Touch down: the window is emptied and takes no audio until `resume`.
    func suspend() {
        lock.lock(); defer { lock.unlock() }
        suspended = true
        clearLocked()
    }

    /// Release: an empty window, open for audio again.
    func resume() {
        lock.lock(); defer { lock.unlock() }
        clearLocked()
        suspended = false
    }

    /// The engine is stopping: an utterance in progress ends here, so what was
    /// said is still settled.
    func closeOpenUtterance() {
        lock.lock(); defer { lock.unlock() }
        guard let last = marks.indices.last, marks[last].end == nil else { return }
        if marks[last].loud >= Segmenter.minSpeechSamples {
            marks[last].end = samples.count
        } else {
            dropLastLocked()
        }
    }

    private func clearLocked() {
        samples.removeAll()
        marks.removeAll()
        appended = 0
        generation += 1
    }

    func snapshot() -> Snapshot? {
        lock.lock(); defer { lock.unlock() }
        guard let first = marks.first else { return nil }
        let end = first.end ?? samples.count
        return Snapshot(
            generation: generation,
            samples: Array(samples[0..<end]),
            closed: first.end != nil,
            speechStartedAt: first.startedAt,
            loudSamples: first.loud,
            appended: appended
        )
    }

    /// Drops the first `count` samples (settled audio) if the window is still
    /// the one the snapshot came from. False means the result is stale and must
    /// not be settled.
    func advance(by count: Int, generation expected: Int) -> Bool {
        lock.lock(); defer { lock.unlock() }
        guard expected == generation else { return false }
        shiftLocked(by: min(max(0, count), samples.count))
        return true
    }

    func isCurrent(_ expected: Int) -> Bool {
        lock.lock(); defer { lock.unlock() }
        return expected == generation
    }

    private func shiftLocked(by count: Int) {
        guard count > 0 else { return }
        samples.removeFirst(count)
        for index in marks.indices {
            marks[index].start = max(0, marks[index].start - count)
            marks[index].end = marks[index].end.map { $0 - count }
        }
        // A closed utterance whose audio is all gone is done.
        marks.removeAll { mark in
            if let end = mark.end { return end <= 0 }
            return false
        }
    }
}

/// Keeps the microphone open while the app is in the foreground and feeds the
/// top half's audio (16 kHz mono Float) into `window`.
///
/// D34 hold routing. While he holds the bottom half, every tap buffer goes, in
/// the input's native format, to the hold sink (his English recognizer) and
/// NOTHING is fed to the gate or the window: the window is emptied and
/// suspended when the hold starts and emptied again when it ends, the gate's
/// utterance in progress is discarded at both ends, and the gate stays deaf
/// for `releaseMute` after release so the tail of his voice still in the pipe
/// cannot open a top-half utterance. The hold state lives under `holdLock`
/// because the main thread sets it and the audio tap thread reads it. It
/// survives an engine restart (headset, phone call), so a restart mid-hold can
/// never send his voice to the top half.
final class MicCapture {
    let window = LiveWindow()
    private let engine = AVAudioEngine()
    /// Tap thread only (and `open`, before the tap exists).
    private var segmenter = Segmenter()
    private var lastSpeaking = false

    /// After release, how long the gate ignores the microphone.
    static let releaseMute: TimeInterval = 0.5
    private let holdLock = NSLock()
    /// Guarded by holdLock. Non-nil exactly while he holds.
    private var holdSink: (@Sendable (AVAudioPCMBuffer) -> Void)?
    /// Guarded by holdLock. Set at both ends of a hold; the tap thread then
    /// discards the gate's utterance in progress before using the buffer.
    private var discardPending = false
    /// Guarded by holdLock. The gate ignores audio until this moment.
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
        let (stateStream, stateContinuation) = AsyncStream.makeStream(of: MicState.self, bufferingPolicy: .bufferingNewest(8))
        self.states = stateStream
        self.stateContinuation = stateContinuation
        observeInterruptions()
    }

    deinit {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
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

    /// Touch down on the bottom half. The window is suspended first, so a tap
    /// buffer already past the routing check can no longer reach it; from the
    /// next tap buffer on, audio goes to `sink` only (called on the audio tap
    /// thread) and the top half hears nothing.
    func beginHold(sink: @escaping @Sendable (AVAudioPCMBuffer) -> Void) {
        window.suspend()
        holdLock.lock()
        holdSink = sink
        discardPending = true
        mutedUntil = nil
        holdLock.unlock()
        report(.holding)
    }

    /// Release. The sink gets no more buffers; the top half resumes after
    /// `releaseMute` with a clean gate and an empty window.
    func endHold() {
        holdLock.lock()
        holdSink = nil
        discardPending = true
        mutedUntil = Date().addingTimeInterval(Self.releaseMute)
        holdLock.unlock()
        // After the mute is set: a buffer arriving now is muted, so nothing
        // from his hold can enter the window being reopened.
        window.resume()
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
            // the gate, not even resampled.
            guard self.routeOutsideGate(buffer) == false else { return }
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
        window.closeOpenUtterance()
        // The audio session is left active on purpose: deactivating it can itself
        // fire a configuration change, which would restart the engine in a loop.
        report(.off)
    }

    /// Audio tap thread. True when the buffer must not reach the gate: it went
    /// to his hold, or the gate is muted just after a release.
    private func routeOutsideGate(_ buffer: AVAudioPCMBuffer) -> Bool {
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
        let step = segmenter.push(samples)
        if step.started {
            // The wall clock of the utterance's first sample (the pre-roll's
            // start), so a time inside the window maps to a time of day.
            let startedAt = Date().addingTimeInterval(-Double(step.audio.count) / Double(Segmenter.sampleRate))
            window.speechStarted(step.audio, loud: step.loudSamples, at: startedAt)
        } else if !step.audio.isEmpty {
            window.speechContinued(step.audio, loud: step.loudSamples)
        }
        if step.ended {
            window.speechEnded(enoughSpeech: step.enoughSpeech)
        }
        if step.speaking != lastSpeaking {
            lastSpeaking = step.speaking
            report(step.speaking ? .hearing : .listening)
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
