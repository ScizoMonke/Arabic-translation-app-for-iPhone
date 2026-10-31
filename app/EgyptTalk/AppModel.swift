import AVFoundation
import Foundation
import NaturalLanguage
import SwiftUI
import Translation
import UIKit

/// One line in the top half: English for what was said around him.
struct TopLine: Identifiable {
    let id = UUID()
    let english: String
    let note: String?
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

/// D34: the top half listens all the time and treats everything as Arabic; the
/// bottom half works only while he presses and holds it. Who is speaking is
/// never guessed.
@MainActor
final class AppModel: ObservableObject {
    enum Phase: Equatable {
        case checking
        case needsDownload
        case downloading(String, Double)
        case preparing(String)
        case ready
        case failed(String)
    }

    @Published private(set) var phase: Phase = .checking
    @Published private(set) var micState: MicState = .off
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

    /// His sentences wait here for the Egyptian model, so a slow generation
    /// never holds up Whisper or the top half: a conversation does not wait.
    private let mySentences: AsyncStream<MySentence>
    private let mySentencesContinuation: AsyncStream<MySentence>.Continuation

    /// Keeps the views fast over a long day; the session log keeps everything.
    private let maxLinesOnScreen = 300

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
        Transcriber.localModelFolder() != nil && ModelDownloader.localModelFile() != nil
    }

    func launch() async {
        await refreshTranslationStatus()
        guard phase == .checking else { return }
        if everythingDownloaded {
            await prepareModels()
        } else {
            phase = .needsDownload
        }
    }

    /// Whatever is missing, in order: Whisper (about 950 MB), then the Egyptian
    /// model (about 2.5 GB). Each resumes where it stopped when tapped again.
    func downloadModels() async {
        if Transcriber.localModelFolder() == nil {
            let label = "Speech model (1 of 2, about 950 MB)"
            phase = .downloading(label, 0)
            do {
                try await transcriber.download { fraction in
                    Task { @MainActor in self.reportDownload(label, fraction) }
                }
            } catch {
                phase = .failed("Speech model download failed. Check Wi-Fi and tap Try again. (\(error.localizedDescription))")
                return
            }
        }
        if ModelDownloader.localModelFile() == nil {
            let label = "Egyptian model (2 of 2, about 2.5 GB)"
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
        await prepareModels()
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

    /// R10/R13: the two models load one after the other, never at once, with a
    /// memory line in the log after each, so a spike can be told apart from a
    /// steady state.
    private func prepareModels() async {
        phase = .preparing("Preparing the speech model for this phone. The first time can take several minutes.")
        do {
            let promptNote = try await transcriber.load()
            logDiagnostic("Whisper loaded, \(promptNote)")
        } catch {
            phase = .failed("Could not load the speech model. (\(error.localizedDescription))")
            return
        }
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
        showStatus("Ready. Speech: \(Transcriber.modelVariant). Egyptian: \(ModelDownloader.fileName).")
        startPipelineIfNeeded()
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

    func refreshTranslationStatus() async {
        translationStatus = await translator.status()
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

    private func startPipelineIfNeeded() {
        guard !pipelineStarted else { return }
        pipelineStarted = true
        Task {
            for await state in mic.states {
                micState = state
            }
        }
        Task {
            // One utterance at a time through Whisper; the stream buffers while
            // Whisper is busy.
            for await utterance in mic.utterances {
                await handleTheirs(utterance)
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

    // MARK: Pipeline

    /// D36: Whisper translate with the English prompt; if the output is not
    /// English, Whisper transcribe plus Apple Translation; otherwise nothing is
    /// shown. The top half shows English or nothing.
    private func handleTheirs(_ utterance: Utterance) async {
        isWorking = true
        defer { isWorking = false }

        let translated: String?
        do {
            translated = try await transcriber.translate(utterance.samples)
        } catch {
            showStatus("Could not process that sentence. (\(error.localizedDescription))")
            return
        }
        guard let translated else { return }   // Whisper judged it non-speech

        let first = Self.englishCheck(translated)
        if first.isEnglish {
            showTop(english: translated, note: nil, path: "translate", utteranceEnd: utterance.endedAt)
            logMemory("after their sentence")
            return
        }

        var reason = "translate output is \(first.label)"
        var arabic: String?
        if await translator.status() == .installed {
            do {
                arabic = try await transcriber.transcribeArabic(utterance.samples)
                if arabic == nil { reason += "; Arabic pass heard no speech" }
            } catch {
                reason += "; Arabic pass failed (\(error.localizedDescription))"
            }
            if let arabic {
                if let english = await translator.toEnglish(arabic) {
                    let second = Self.englishCheck(english)
                    if second.isEnglish {
                        logDiagnostic("\(reason); translate raw \"\(ScriptGuard.escapeForLog(translated))\"; recovered by Apple Translate")
                        showTop(english: english, note: "via Apple Translate", path: "fallback-apple",
                                utteranceEnd: utterance.endedAt)
                        logMemory("after their sentence")
                        return
                    }
                    reason += "; Apple output is \(second.label)"
                } else {
                    reason += "; Apple Translate returned nothing"
                }
            }
        } else {
            reason += "; Apple Arabic pack not installed"
        }
        logDroppedTop(reason: reason, translated: translated, arabic: arabic, utteranceEnd: utterance.endedAt)
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
    // The only four ways text reaches the screen. Each cleans with ScriptGuard
    // (D5); the three lasting ones log exactly what they show. The live heard
    // line is transient: it becomes the card's "You:" line, which is logged.
    // The log-only helpers below them write lines that are never shown, also
    // cleaned.

    private func showTop(english: String, note: String?, path: String, utteranceEnd: Date) {
        let text = ScriptGuard.clean(english)
        let cleanNote = note.map { ScriptGuard.clean($0) }
        guard !text.isEmpty else {
            logDroppedTop(reason: "nothing left after the script guard", translated: english, arabic: nil,
                          utteranceEnd: utteranceEnd)
            return
        }
        topLines.append(TopLine(english: text, note: cleanNote))
        if topLines.count > maxLinesOnScreen {
            topLines.removeFirst(topLines.count - maxLinesOnScreen)
        }
        let shownAt = Date()
        log.append("THEM: \(text)" + (cleanNote.map { "  (\($0))" } ?? "") + " [\(path)]")
        log.append("TIME them: utterance-end \(log.clock(utteranceEnd)) | line \(log.clock(shownAt)) "
            + "(+\(Self.milliseconds(utteranceEnd, shownAt)) ms) [\(path)]")
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

    /// D36 "dropped" path: nothing is shown; the raw outputs go to the log with
    /// Arabic script escaped (D5), so R27 can be counted afterwards.
    private func logDroppedTop(reason: String, translated: String, arabic: String?, utteranceEnd: Date) {
        let droppedAt = Date()
        var line = "THEM dropped: \(reason) | translate raw \"\(ScriptGuard.escapeForLog(translated))\""
        if let arabic {
            line += " | arabic raw \"\(ScriptGuard.escapeForLog(arabic))\""
        }
        log.append(ScriptGuard.clean(line))
        log.append("TIME them: utterance-end \(log.clock(utteranceEnd)) | dropped \(log.clock(droppedAt)) "
            + "(+\(Self.milliseconds(utteranceEnd, droppedAt)) ms) [dropped]")
    }

    private func logDiagnostic(_ message: String) {
        log.append("  diag: \(ScriptGuard.clean(message))")
    }

    private func logMemory(_ moment: String) {
        log.append("\(MemoryProbe.line()) (\(moment))")
    }
}
