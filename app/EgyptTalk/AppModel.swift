import AVFoundation
import Foundation
import NaturalLanguage
import SwiftUI
import Translation
import UIKit

/// One settled line in the top half: English for something said around him.
/// Never changes once made (D43). `utterance` groups the lines of one stretch
/// of speech, so the view can make the current one larger.
struct TopLine: Identifiable {
    let id = UUID()
    let english: String
    let utterance: Int
}

/// One card in the bottom half (D13): what he said, what to say, what it means,
/// and where the Latin line came from.
struct BottomLine: Identifiable {
    let id = UUID()
    let heard: String
    let latin: String
    let gloss: String
    let source: String
}

/// One of his sentences on its way to the Egyptian model, with the two times
/// the bottom TIME line reports (R28).
struct MySentence: Sendable {
    let english: String
    let releasedAt: Date
    let heardFinalAt: Date
}

/// How the top half turns Arabic into English this session, chosen at load.
enum TopMode: Equatable, Sendable {
    /// D43: turbo transcribes a rolling window about every second; Apple
    /// translates. Needs the Apple Arabic pack.
    case live
    /// R31: turbo would not load, so large-v3 transcribes the rolling window,
    /// every two seconds because it is about three times slower.
    case liveSlow
    /// Pack missing: today's path, large-v3 translates each utterance after
    /// the speaker pauses (D16, D36).
    case perUtterance

    /// Seconds of new audio between decodes of the rolling window.
    var tick: Double {
        switch self {
        case .live: return 1.0
        case .liveSlow: return 2.0
        case .perUtterance: return 0
        }
    }

    var label: String {
        switch self {
        case .live: return "live"
        case .liveSlow: return "live, slower model"
        case .perUtterance: return "after each pause (Apple Arabic pack missing)"
        }
    }
}

/// D34: the top half listens all the time and treats everything as Arabic; the
/// bottom half works only while he presses and holds it. Who is speaking is
/// never guessed.
@MainActor
final class AppModel: ObservableObject {
    enum Phase: Equatable {
        case checking
        case needsDownload
        case downloading(String, Double)
        /// D43: setup stops here until Apple's Arabic pack is installed.
        case needsArabicPack
        case preparing(String)
        case ready
        case failed(String)
    }

    @Published private(set) var phase: Phase = .checking
    @Published private(set) var micState: MicState = .off
    /// True while today's path (per utterance) works on a sentence.
    @Published private(set) var isWorking = false
    /// True while the Egyptian model works on one of his sentences.
    @Published private(set) var isComposing = false
    /// D34: true from touch down to release on the bottom half.
    @Published private(set) var isHolding = false
    /// His English as Apple hears it, growing while he holds, then the final
    /// text until his card appears. Transient, like the progress indicators:
    /// the card and the log keep the final English.
    @Published private(set) var liveHeard = ""
    /// Why holding cannot work right now (permission, offline English), or nil.
    @Published private(set) var englishProblem: String?
    @Published private(set) var topLines: [TopLine] = []
    /// D43: English for what is still being said, replaced at every decode
    /// and shown lighter than the settled lines. Transient: what it becomes is
    /// settled and logged.
    @Published private(set) var liveTail = ""
    @Published private(set) var topMode: TopMode?
    @Published private(set) var bottomLines: [BottomLine] = []
    @Published private(set) var statusMessage: String?
    @Published private(set) var translationStatus: LanguageAvailability.Status?

    private let transcriber = Transcriber()
    private let translator: AppleTranslator
    private let romanizer: EgyptianRomanizer
    private let nileDownloader = ModelDownloader()
    private let listener = EnglishListener()
    private let log = SessionLog()
    private let mic = MicCapture()
    private var pipelineStarted = false
    private var isForeground = true

    /// The hold in progress, if any.
    private var capture: EnglishCapture?
    private var holdStartedAt = Date()
    /// Counts holds, so the safety cap of an old hold can never end a new one.
    private var holdNumber = 0
    /// A stuck touch must not keep the top half deaf: a hold ends by itself after
    /// this long (also about the longest a single Apple recognition runs).
    static let maxHold: Duration = .seconds(60)
    /// D34: a shorter hold that heard nothing is a stray touch.
    static let minHold: TimeInterval = 0.3
    /// After release, the longest wait for Apple's final English before the last
    /// partial result is used instead.
    static let finalResultTimeout: Duration = .seconds(2)

    /// D43 settle rule (see `settleCount`). Measured on the PC with a Python
    /// twin of this loop and faster-whisper turbo on 30 Egyptian clips: 209
    /// settle points, 2 with the boundary word repeated, word error against the
    /// reference 0.40 streamed versus 0.43 for one offline pass.
    static let settleAgeSeconds: Float = 4.0
    static let settleForceWindowSeconds: Float = 24.0
    /// Today's path: an utterance this long is taken without waiting for a pause.
    static let utteranceCutSeconds = 25
    private static let idlePoll: Duration = .milliseconds(100)

    /// D43 gate, first setup only: once passed, a pack that later goes
    /// missing sends the top half to today's path instead of locking him out.
    private static let packGateKey = "arabicPackGatePassed"

    /// His sentences wait here for the Egyptian model, so a slow generation
    /// never holds up Whisper or the top half: a conversation does not wait.
    private let mySentences: AsyncStream<MySentence>
    private let mySentencesContinuation: AsyncStream<MySentence>.Continuation

    /// Keeps the views fast over a long day; the session log keeps everything.
    private let maxLinesOnScreen = 300
    /// Counts stretches of speech in the top half, for TopLine.utterance.
    private var utteranceNumber = 0

    init() {
        let translator = AppleTranslator()
        self.translator = translator
        self.romanizer = EgyptianRomanizer(translator: translator)
        let (stream, continuation) = AsyncStream.makeStream(of: MySentence.self, bufferingPolicy: .unbounded)
        self.mySentences = stream
        self.mySentencesContinuation = continuation
    }

    // MARK: Setup

    private var everythingDownloaded: Bool {
        SpeechModel.allCases.allSatisfy { Transcriber.localModelFolder($0) != nil }
            && ModelDownloader.localModelFile() != nil
    }

    func launch() async {
        await refreshTranslationStatus()
        guard phase == .checking else { return }
        if everythingDownloaded {
            await passPackGateOrWait()
        } else {
            phase = .needsDownload
        }
    }

    /// Whatever is missing, in order: the live speech model, the full speech
    /// model, then the Egyptian model. Each resumes where it stopped when
    /// tapped again (the speech models file by file, the Egyptian one by byte).
    func downloadModels() async {
        let steps: [(SpeechModel, String)] = [
            (.live, "Live speech model (1 of 3, \(SpeechModel.live.sizeLabel))"),
            (.full, "Backup speech model (2 of 3, \(SpeechModel.full.sizeLabel))"),
        ]
        for (model, label) in steps where Transcriber.localModelFolder(model) == nil {
            phase = .downloading(label, 0)
            do {
                try await transcriber.download(model) { fraction in
                    Task { @MainActor in self.reportDownload(label, fraction) }
                }
            } catch {
                phase = .failed("Speech model download failed. Check Wi-Fi and tap Try again. (\(error.localizedDescription))")
                return
            }
        }
        if ModelDownloader.localModelFile() == nil {
            let label = "Egyptian model (3 of 3, about 2.5 GB)"
            phase = .downloading(label, 0)
            do {
                try await nileDownloader.download { fraction in
                    Task { @MainActor in self.reportDownload(label, fraction) }
                }
            } catch {
                phase = .failed("Egyptian model download stopped. Check Wi-Fi and tap Try again; it continues where it stopped. (\(error.localizedDescription))")
                return
            }
        }
        await passPackGateOrWait()
    }

    /// Progress callbacks can arrive after a download returned; only the phase
    /// for the same download may be updated.
    private func reportDownload(_ label: String, _ fraction: Double) {
        if case .downloading(let current, _) = phase, current == label {
            phase = .downloading(label, fraction)
        }
    }

    /// After a failed download, Try again resumes the download directly.
    func retry() async {
        if everythingDownloaded {
            phase = .checking
            await launch()
        } else {
            await downloadModels()
        }
    }

    /// D43: the first setup does not reach the split screen without Apple's
    /// Arabic pack. The setup screen's download button finishes the gate
    /// through `refreshTranslationStatus`.
    private func passPackGateOrWait() async {
        if translationStatus == .installed {
            UserDefaults.standard.set(true, forKey: Self.packGateKey)
        }
        if UserDefaults.standard.bool(forKey: Self.packGateKey) {
            await prepareModels()
        } else {
            phase = .needsArabicPack
        }
    }

    /// Offered only when Apple says the pack does not exist for this phone:
    /// the app then runs today's slower top half instead of never opening.
    func continueWithoutPack() async {
        guard phase == .needsArabicPack, translationStatus == .unsupported else { return }
        UserDefaults.standard.set(true, forKey: Self.packGateKey)
        await prepareModels()
    }

    /// R10/R13: the models load one after the other, never at once, with a
    /// memory line in the log after each, so a spike can be told apart from a
    /// steady state. Only one Whisper model is loaded, chosen by the pack.
    private func prepareModels() async {
        phase = .preparing("Preparing the speech model for this phone. The first time can take several minutes.")
        let packInstalled = await translator.status() == .installed
        translationStatus = packInstalled ? .installed : translationStatus

        // If iOS killed the app while turbo loaded last time (memory, R10/R31),
        // the marker is still set: use large-v3 this once, so a model that
        // cannot load never locks him out. The next launch tries turbo again.
        let liveMarker = "liveWhisperLoadInProgress"
        var mode: TopMode = .perUtterance
        var note = ""
        do {
            if !packInstalled {
                note = try await transcriber.load(.full)
                mode = .perUtterance
            } else if UserDefaults.standard.bool(forKey: liveMarker) {
                UserDefaults.standard.set(false, forKey: liveMarker)
                logDiagnostic("\(Transcriber.liveVariant) skipped: loading it ended the app last time")
                note = try await transcriber.load(.full)
                mode = .liveSlow
            } else {
                UserDefaults.standard.set(true, forKey: liveMarker)
                do {
                    note = try await transcriber.load(.live)
                    mode = .live
                } catch {
                    // R31: WhisperKit refused turbo on this phone.
                    logDiagnostic("\(Transcriber.liveVariant) did not load (\(error.localizedDescription)); using large-v3")
                    note = try await transcriber.load(.full)
                    mode = .liveSlow
                }
                UserDefaults.standard.set(false, forKey: liveMarker)
            }
        } catch {
            UserDefaults.standard.set(false, forKey: liveMarker)
            phase = .failed("Could not load the speech model. (\(error.localizedDescription))")
            return
        }
        topMode = mode
        logDiagnostic("Whisper: \(note); top half: \(mode.label)")
        logMemory("after Whisper load")

        do {
            let book = try Phrasebook.loadBundled()
            await romanizer.installPhrasebook(book)
            showStatus(book.map { "Phrasebook: \($0.entries.count) phrases." } ?? "No phrasebook in this build; every sentence goes to the model.")
        } catch {
            showStatus("Phrasebook could not be read, so it is skipped. (\(error.localizedDescription))")
        }

        // A failed Egyptian model must not cost him the top half: the app opens
        // anyway and the bottom half says what is wrong on each card.
        // If iOS killed the app during the previous load (memory, R10), the
        // marker below is still set: skip the load once, so a model that cannot
        // fit never locks him out of the top half. The next launch tries again.
        let loadMarker = "egyptianModelLoadInProgress"
        if UserDefaults.standard.bool(forKey: loadMarker) {
            UserDefaults.standard.set(false, forKey: loadMarker)
            showStatus("Egyptian model skipped this time: loading it ended the app last time (memory). Top half only. Reopen the app to try again.")
        } else if let file = ModelDownloader.localModelFile() {
            phase = .preparing("Loading the Egyptian model.")
            logMemory("before Egyptian model load")
            UserDefaults.standard.set(true, forKey: loadMarker)
            do {
                let description = try await romanizer.loadModel(path: file.path)
                logDiagnostic("Egyptian model loaded: \(description)")
            } catch {
                showStatus("The Egyptian model could not load; the bottom half will not work. (\(error.localizedDescription))")
            }
            UserDefaults.standard.set(false, forKey: loadMarker)
            logMemory("after Egyptian model load")
        }

        phase = .ready
        showStatus("Ready. Top half: \(mode.label). Egyptian: \(ModelDownloader.fileName).")
        startPipelineIfNeeded(mode)
        let granted = await AVAudioApplication.requestRecordPermission()
        if !granted {
            showStatus("Microphone is off for Egypt Talk. Turn it on in Settings > Apps > Egypt Talk.")
            return
        }
        if isForeground {
            setListening(true)
        }
        await prepareEnglish()
    }

    /// D35: permission for Apple's recognizer and a check that English works
    /// offline. Run again on return to the app, in case he fixed it in Settings.
    private func prepareEnglish() async {
        let readiness = await listener.prepare()
        englishProblem = listener.problem.map { ScriptGuard.clean($0) }
        if let problem = englishProblem {
            showStatus(problem)
        }
        logDiagnostic("English recognizer: \(readiness)")
    }

    /// Also finishes the D43 gate: when the pack arrives while setup waits for
    /// it, loading continues by itself.
    func refreshTranslationStatus() async {
        let status = await translator.status()
        translationStatus = status
        if status == .installed {
            if phase == .needsArabicPack {
                UserDefaults.standard.set(true, forKey: Self.packGateKey)
                // Callers are view tasks that SwiftUI cancels when the setup
                // screen goes away; the minutes-long load must not belong to
                // them. The phase changes first, so a second call cannot start
                // a second load.
                phase = .preparing("Preparing the speech model for this phone. The first time can take several minutes.")
                Task { await self.prepareModels() }
            } else if phase == .ready, topMode == .perUtterance {
                showStatus("Apple Arabic pack installed. Close and reopen Egypt Talk for the live top half.")
            }
        }
    }

    // MARK: Lifecycle

    func scenePhaseChanged(_ newPhase: ScenePhase) {
        switch newPhase {
        case .active:
            isForeground = true
            // He will not touch the phone mid-conversation, so it must not lock.
            UIApplication.shared.isIdleTimerDisabled = true
            if phase == .ready {
                setListening(true)
                if englishProblem != nil {
                    Task { await prepareEnglish() }
                }
            }
        case .background:
            isForeground = false
            UIApplication.shared.isIdleTimerDisabled = false
            // A hold cannot outlive the app being in front; end it before the mic
            // stops so the top half is never left suspended.
            endHold()
            setListening(false)
        default:
            // .inactive covers permission alerts and Control Center; keep listening.
            break
        }
    }

    private func setListening(_ on: Bool) {
        if on {
            do {
                try mic.start()
            } catch {
                showStatus("Microphone could not start. (\(error.localizedDescription))")
            }
        } else {
            mic.stop()
        }
    }

    private func startPipelineIfNeeded(_ mode: TopMode) {
        guard !pipelineStarted else { return }
        pipelineStarted = true
        Task {
            for await state in mic.states {
                micState = state
            }
        }
        Task {
            if mode == .perUtterance {
                await runUtteranceTop()
            } else {
                await runLiveTop(tick: mode.tick)
            }
        }
        Task {
            // His sentences, one at a time through the Egyptian model, in parallel
            // with Whisper working on whatever is said next.
            for await sentence in mySentences {
                await deliverMine(sentence)
            }
        }
    }

    // MARK: Hold to talk (D34, D35)

    /// Touch down on the bottom half. From here until release the microphone
    /// feeds only Apple's English recognizer; the top half hears nothing. That
    /// holds for EVERY hold, including one Apple cannot recognize right now
    /// (no permission, no offline English): his voice must never reach Whisper
    /// (D34), so the top half pauses either way and the audio is then discarded.
    func beginHold() {
        guard phase == .ready, !isHolding else { return }
        let capture = listener.begin(onPartial: { [weak self] partial in
            self?.showLiveHeard(partial)
        })
        self.capture = capture
        if let capture {
            let request = capture.request
            // Runs on the audio tap thread; the request is the only thing it touches.
            mic.beginHold { buffer in
                request.append(buffer)
            }
        } else {
            mic.beginHold { _ in }
            showStatus(listener.problem ?? "English recognition is not available this moment. Let go and try again.")
        }
        // The window under the tail was just emptied; its English goes too.
        liveTail = ""
        isHolding = true
        holdStartedAt = Date()
        liveHeard = ""
        holdNumber += 1
        let number = holdNumber
        Task { [weak self] in
            // Task.sleep throws only on cancellation; this task is never cancelled.
            try? await Task.sleep(for: AppModel.maxHold)
            guard let self, self.isHolding, self.holdNumber == number else { return }
            self.showStatus("A hold of over a minute was ended automatically.")
            self.endHold()
        }
    }

    /// Release (or the app leaving the foreground, or the safety cap). The top
    /// half resumes; his English is finalized and queued for the model.
    func endHold() {
        guard isHolding else { return }
        let releasedAt = Date()
        isHolding = false
        mic.endHold()
        guard let capture else {
            // A hold Apple could not hear: nothing to finalize.
            liveHeard = ""
            return
        }
        self.capture = nil

        let heldFor = releasedAt.timeIntervalSince(holdStartedAt)
        if heldFor < Self.minHold && capture.latest.isEmpty {
            capture.cancel()
            liveHeard = ""
            logDiagnostic("hold of \(Self.milliseconds(holdStartedAt, releasedAt)) ms with no speech ignored")
            return
        }

        Task {
            let english = await capture.finish(timeout: Self.finalResultTimeout)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let heardFinalAt = Date()
            if let failure = capture.failure {
                logDiagnostic("English recognizer: \(failure)")
            }
            guard !english.isEmpty else {
                if !isHolding { liveHeard = "" }
                showStatus("Did not catch any English. Hold, speak, then let go.")
                log.append("TIME me: release \(log.clock(releasedAt)) | heard-final \(log.clock(heardFinalAt)) "
                    + "(+\(Self.milliseconds(releasedAt, heardFinalAt)) ms) | no card, nothing heard")
                return
            }
            if !isHolding { showLiveHeard(english) }
            mySentencesContinuation.yield(MySentence(english: english, releasedAt: releasedAt, heardFinalAt: heardFinalAt))
        }
    }

    // MARK: Top half, live (D43)

    /// The rolling window loop. Each pass: snapshot the window; when due,
    /// transcribe it, settle a prefix of Whisper's segments, advance the window
    /// past them, translate the settled Arabic (appended for good) and the
    /// rest (the lighter live tail). One decode at a time: a pass that would
    /// fall while a decode runs simply does not happen, nothing queues. The
    /// microphone only appends to the window and never waits on this loop.
    private func runLiveTop(tick: Double) async {
        let window = mic.window
        let rate = Segmenter.sampleRate
        let tickSamples = Int(tick * Double(rate))
        let minimumSamples = Int(Transcriber.minimumDecodeSeconds * Float(rate))
        var generation = -1
        var lastDecodeAppended = 0
        /// The previous decode of this same window (same start), for the
        /// two-decode agreement.
        var previous: [HeardSegment] = []
        /// The stretch of speech the window is on: its start (also its key),
        /// seconds already settled and cut from it, and when English for it
        /// first reached the screen.
        var speechStart: Date?
        var settledSeconds: Double = 0
        var firstLiveAt: Date?

        while true {
            guard let snap = window.snapshot() else {
                try? await Task.sleep(for: Self.idlePoll)
                continue
            }
            if snap.generation != generation {
                generation = snap.generation
                previous = []
                lastDecodeAppended = 0
            }
            if snap.speechStartedAt != speechStart {
                speechStart = snap.speechStartedAt
                settledSeconds = 0
                firstLiveAt = nil
                previous = []
                utteranceNumber += 1
            }
            let due = snap.closed
                || (snap.loudSamples >= Segmenter.minSpeechSamples
                    && snap.samples.count >= minimumSamples
                    && snap.appended - lastDecodeAppended >= tickSamples)
            guard due else {
                try? await Task.sleep(for: Self.idlePoll)
                continue
            }
            lastDecodeAppended = snap.appended

            let segments: [HeardSegment]
            do {
                segments = try await transcriber.transcribeSegments(snap.samples)
            } catch {
                showStatus("Could not process what was said. (\(error.localizedDescription))")
                if snap.closed {
                    // Retrying the same closed audio would loop on the same error.
                    _ = window.advance(by: snap.samples.count, generation: snap.generation)
                    logTopFailure(outcome: "error: \(error.localizedDescription)", speechStart: snap.speechStartedAt)
                }
                try? await Task.sleep(for: .seconds(1))
                continue
            }

            let windowSeconds = Float(snap.samples.count) / Float(rate)
            var settle = snap.closed ? segments.count
                : Self.settleCount(current: segments, previous: previous, windowSeconds: windowSeconds)
            var cut = snap.samples.count
            if !snap.closed && settle > 0 {
                // Cut where the first unsettled segment starts, never before the
                // end of the last settled one, so no settled audio is decoded twice.
                let boundary = max(segments[settle - 1].end, segments[settle].start)
                cut = min(snap.samples.count, Int((boundary * Float(rate)).rounded()))
                if cut <= 0 {
                    settle = 0   // timestamps that cut nothing would settle words twice
                }
            }
            if snap.closed || settle > 0 {
                guard window.advance(by: cut, generation: snap.generation) else { continue }
            } else if !window.isCurrent(snap.generation) {
                continue
            }

            let cutSeconds = Double(cut) / Double(rate)
            let settledBase = settledSeconds
            if snap.closed {
                previous = []
            } else if settle > 0 {
                let shift = Float(cutSeconds)
                previous = segments[settle...].map {
                    HeardSegment(text: $0.text, start: $0.start - shift, end: $0.end - shift)
                }
                settledSeconds += cutSeconds
            } else {
                previous = segments
            }

            for segment in segments[..<settle] {
                let english = await translator.toEnglish(segment.text)
                let spokenEnd = snap.speechStartedAt.addingTimeInterval(settledBase + Double(segment.end))
                settleTop(arabic: segment.text, english: english, speechStart: snap.speechStartedAt,
                          spokenEnd: spokenEnd, firstLiveAt: &firstLiveAt)
            }

            let tailArabic = snap.closed ? "" : segments[settle...].map(\.text).joined(separator: " ")
            if tailArabic.isEmpty {
                liveTail = ""
            } else {
                let english = await translator.toEnglish(tailArabic)
                // Checked after Apple answers: a hold may have emptied the
                // window meanwhile, and its tail must not come back.
                if !window.isCurrent(snap.generation) || isHolding {
                    liveTail = ""
                } else if let english, let shown = Self.displayableEnglish(english) {
                    liveTail = shown
                    if firstLiveAt == nil { firstLiveAt = Date() }
                } else if settle > 0 {
                    // The old tail would repeat words that just settled above it.
                    liveTail = ""
                }
            }
            if snap.closed {
                if segments.isEmpty && settledBase == 0 {
                    // R29: a stretch of speech that settled nothing still gets a TIME line.
                    logTopFailure(outcome: "no speech", speechStart: snap.speechStartedAt)
                }
                logMemory("after their speech")
            }
        }
    }

    /// D43 settle rule. Never the last segment of a decode (it may end inside a
    /// word). The others settle, oldest first and only as an unbroken prefix,
    /// when one of these holds:
    ///   - its text (letters only) is what the previous decode of the same
    ///     window had at the same position;
    ///   - it ended `settleAgeSeconds` or more before the newest audio;
    ///   - the window has reached `settleForceWindowSeconds` (Whisper sees 30 s).
    /// A closed utterance settles everything, without this function.
    static func settleCount(current: [HeardSegment], previous: [HeardSegment], windowSeconds: Float) -> Int {
        var count = 0
        for index in 0..<max(0, current.count - 1) {
            let segment = current[index]
            let stable = index < previous.count && letters(previous[index].text) == letters(segment.text)
            let old = windowSeconds - segment.end >= settleAgeSeconds
            let forced = windowSeconds >= settleForceWindowSeconds
            guard stable || old || forced else { break }
            count = index + 1
        }
        return count
    }

    /// Punctuation and spacing wobble between decodes of the same audio.
    private static func letters(_ text: String) -> String {
        String(text.filter { $0.isLetter || $0.isNumber })
    }

    /// English that may be shown: Arabic script removed (D5), letters left, and
    /// not a known hallucination (checked after translation on every path).
    private static func displayableEnglish(_ english: String) -> String? {
        let text = ScriptGuard.clean(english)
        guard Transcriber.isText(text), !Transcriber.isKnownHallucination(text) else { return nil }
        return text
    }

    // MARK: Top half, per utterance (pack missing)

    /// Today's path, kept for a phone without Apple's Arabic pack: wait for the
    /// speaker to pause (or 25 s), then Whisper large-v3 translates the
    /// utterance with the English prompt, and NaturalLanguage must call the
    /// result English (D36). Utterances that ended before a hold are still
    /// handled during it (their speech, D42).
    private func runUtteranceTop() async {
        let window = mic.window
        let cutSamples = Self.utteranceCutSeconds * Segmenter.sampleRate
        while true {
            guard let snap = window.snapshot(), snap.closed || snap.samples.count >= cutSamples else {
                try? await Task.sleep(for: Self.idlePoll)
                continue
            }
            let endedAt = Date()
            guard window.advance(by: snap.samples.count, generation: snap.generation) else { continue }
            utteranceNumber += 1
            await handleTheirs(snap.samples, speechStart: snap.speechStartedAt, endedAt: endedAt)
        }
    }

    private func handleTheirs(_ samples: [Float], speechStart: Date, endedAt: Date) async {
        isWorking = true
        defer { isWorking = false }

        let translated: String?
        do {
            translated = try await transcriber.translate(samples)
        } catch {
            showStatus("Could not process that sentence. (\(error.localizedDescription))")
            logTopFailure(outcome: "error: \(error.localizedDescription)", speechStart: speechStart, utteranceEnd: endedAt)
            return
        }
        guard let translated else {
            // Whisper judged it non-speech (R29: still a TIME line).
            logTopFailure(outcome: "no speech", speechStart: speechStart, utteranceEnd: endedAt)
            return
        }
        let check = Self.englishCheck(translated)
        guard check.isEnglish, let english = Self.displayableEnglish(translated) else {
            let reason = check.isEnglish ? "nothing left after the script guard or a known hallucination"
                : "translate output is \(check.label)"
            logDroppedTop(reason: reason, raw: translated, speechStart: speechStart, utteranceEnd: endedAt)
            return
        }
        appendTopLine(english)
        let shownAt = Date()
        log.append("THEM: \(english) [translate]")
        log.append("TIME them: speech-start \(log.clock(speechStart)) | utterance-end \(log.clock(endedAt)) | line \(log.clock(shownAt)) "
            + "(+\(Self.milliseconds(endedAt, shownAt)) ms after utterance-end) [translate]")
        logMemory("after their sentence")
    }

    /// English is what Apple's NaturalLanguage framework calls English, with no
    /// Arabic script in it. Arabic written in Latin letters fails this check.
    private static func englishCheck(_ text: String) -> (isEnglish: Bool, label: String) {
        if ScriptGuard.containsArabic(text) {
            return (false, "Arabic script")
        }
        guard let language = NLLanguageRecognizer.dominantLanguage(for: text) else {
            return (false, "undetermined")
        }
        return (language == .english, "language \(language.rawValue)")
    }

    // MARK: Bottom half

    private func deliverMine(_ sentence: MySentence) async {
        isComposing = true
        defer { isComposing = false }
        let rendering: Rendering
        do {
            rendering = try await romanizer.render(heardEnglish: sentence.english)
        } catch {
            rendering = Rendering(
                heardEnglish: sentence.english,
                latin: "[could not render this one]",
                gloss: "Say it again, shorter or in other words.",
                source: "error",
                diagnostics: ["error: \(error.localizedDescription)"]
            )
        }
        showBottom(rendering)
        let cardAt = Date()
        if !isHolding { liveHeard = "" }
        log.append("TIME me: release \(log.clock(sentence.releasedAt)) | heard-final \(log.clock(sentence.heardFinalAt)) "
            + "(+\(Self.milliseconds(sentence.releasedAt, sentence.heardFinalAt)) ms) | card \(log.clock(cardAt)) "
            + "(+\(Self.milliseconds(sentence.releasedAt, cardAt)) ms after release) [\(ScriptGuard.clean(rendering.source))]")
        logMemory("after my sentence")
    }

    private static func milliseconds(_ from: Date, _ to: Date) -> Int {
        Int((to.timeIntervalSince(from) * 1000).rounded())
    }

    // MARK: Render paths
    // The only ways text reaches the screen. Each cleans with ScriptGuard (D5);
    // the lasting ones log exactly what they show. The live heard line and the
    // live tail are transient: what they become (his card, a settled line) is
    // logged. The log-only helpers below them write lines that are never
    // shown, also cleaned, with Arabic escaped.

    /// One settled segment of the live top half: shown for good if Apple's
    /// English passes, logged either way with the Arabic escaped, so the pairs
    /// can be graded later (R30).
    private func settleTop(arabic: String, english: String?, speechStart: Date, spokenEnd: Date,
                           firstLiveAt: inout Date?) {
        let settledAt = Date()
        let escaped = ScriptGuard.escapeForLog(arabic)
        let outcome: String
        if let english, let shown = Self.displayableEnglish(english) {
            appendTopLine(shown)
            if firstLiveAt == nil { firstLiveAt = settledAt }
            log.append(ScriptGuard.clean("THEM: \(shown) | ar \"\(escaped)\" [live]"))
            outcome = "live"
        } else if let english {
            log.append(ScriptGuard.clean("THEM dropped: Apple output not shown | ar \"\(escaped)\" | en \"\(ScriptGuard.escapeForLog(english))\""))
            outcome = "dropped"
        } else {
            // R29: a translate that returns nothing still gets its TIME line.
            log.append(ScriptGuard.clean("THEM untranslated: Apple Translate returned nothing | ar \"\(escaped)\""))
            outcome = "untranslated"
        }
        let firstLive = firstLiveAt.map { "\(log.clock($0)) (+\(Self.milliseconds(speechStart, $0)) ms)" } ?? "none"
        log.append("TIME them: speech-start \(log.clock(speechStart)) | first-live \(firstLive) | settle \(log.clock(settledAt)) "
            + "(+\(Self.milliseconds(speechStart, settledAt)) ms; \(Self.milliseconds(spokenEnd, settledAt)) ms after its words) [\(outcome)]")
    }

    private func appendTopLine(_ english: String) {
        topLines.append(TopLine(english: english, utterance: utteranceNumber))
        if topLines.count > maxLinesOnScreen {
            topLines.removeFirst(topLines.count - maxLinesOnScreen)
        }
    }

    private func showBottom(_ rendering: Rendering) {
        let line = BottomLine(
            heard: ScriptGuard.clean(rendering.heardEnglish),
            latin: ScriptGuard.clean(rendering.latin),
            gloss: ScriptGuard.clean(rendering.gloss),
            source: ScriptGuard.clean(rendering.source)
        )
        bottomLines.append(line)
        if bottomLines.count > maxLinesOnScreen {
            bottomLines.removeFirst(bottomLines.count - maxLinesOnScreen)
        }
        log.append("ME: heard \"\(line.heard)\" | say \"\(line.latin)\" | \(line.gloss) | [\(line.source)]")
        for diagnostic in rendering.diagnostics {
            logDiagnostic(diagnostic)
        }
    }

    private func showLiveHeard(_ english: String) {
        liveHeard = ScriptGuard.clean(english)
    }

    private func showStatus(_ message: String) {
        let text = ScriptGuard.clean(message)
        statusMessage = text
        log.append("STATUS: \(text)")
    }

    /// Today's path, "dropped": nothing is shown; the raw output goes to the
    /// log with Arabic script escaped (D5), so R27 can be counted afterwards.
    private func logDroppedTop(reason: String, raw: String, speechStart: Date, utteranceEnd: Date) {
        log.append(ScriptGuard.clean("THEM dropped: \(reason) | translate raw \"\(ScriptGuard.escapeForLog(raw))\""))
        logTopFailure(outcome: "dropped", speechStart: speechStart, utteranceEnd: utteranceEnd)
    }

    /// R29: every top-half attempt ends in a TIME line, including the ones
    /// that show nothing.
    private func logTopFailure(outcome: String, speechStart: Date, utteranceEnd: Date? = nil) {
        let at = Date()
        let end = utteranceEnd.map { " | utterance-end \(log.clock($0))" } ?? ""
        log.append(ScriptGuard.clean("TIME them: speech-start \(log.clock(speechStart))\(end) | \(outcome) \(log.clock(at)) "
            + "(+\(Self.milliseconds(speechStart, at)) ms) [\(outcome)]"))
    }

    private func logDiagnostic(_ message: String) {
        log.append("  diag: \(ScriptGuard.clean(message))")
    }

    private func logMemory(_ moment: String) {
        log.append("\(MemoryProbe.line()) (\(moment))")
    }
}
