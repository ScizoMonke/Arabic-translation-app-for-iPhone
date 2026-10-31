import AVFoundation
import Foundation
import SwiftUI
import Translation
import UIKit

/// Manual override for who is speaking (D11). Auto trusts Whisper's language ID.
enum Routing: String, CaseIterable, Identifiable {
    case auto = "Auto"
    case them = "Them"
    case me = "Me"
    var id: String { rawValue }
}

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
    @Published var routing: Routing = .auto
    @Published private(set) var topLines: [TopLine] = []
    @Published private(set) var bottomLines: [BottomLine] = []
    @Published private(set) var statusMessage: String?
    @Published private(set) var translationStatus: LanguageAvailability.Status?

    private let transcriber = Transcriber()
    private let translator: AppleTranslator
    private let romanizer: EgyptianRomanizer
    private let nileDownloader = ModelDownloader()
    private let log = SessionLog()
    private let mic = MicCapture()
    private var pipelineStarted = false
    private var isForeground = true

    /// His own sentences wait here for the Egyptian model, so a slow generation
    /// never holds up Whisper or the top half: a conversation does not wait.
    private let myUtterances: AsyncStream<Heard>
    private let myUtterancesContinuation: AsyncStream<Heard>.Continuation

    /// Keeps the views fast over a long day; the session log keeps everything.
    private let maxLinesOnScreen = 300

    init() {
        let translator = AppleTranslator()
        self.translator = translator
        self.romanizer = EgyptianRomanizer(translator: translator)
        let (stream, continuation) = AsyncStream.makeStream(of: Heard.self, bufferingPolicy: .unbounded)
        self.myUtterances = stream
        self.myUtterancesContinuation = continuation
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

    func retry() async {
        phase = .checking
        await launch()
    }

    /// R10/R13: the two models load one after the other, never at once, with a
    /// memory line in the log after each, so a spike can be told apart from a
    /// steady state.
    private func prepareModels() async {
        phase = .preparing("Preparing the speech model for this phone. The first time can take several minutes.")
        do {
            try await transcriber.load()
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
        if let file = ModelDownloader.localModelFile() {
            phase = .preparing("Loading the Egyptian model.")
            do {
                let description = try await romanizer.loadModel(path: file.path)
                logDiagnostic("Egyptian model loaded: \(description)")
            } catch {
                showStatus("The Egyptian model could not load; the bottom half will not work. (\(error.localizedDescription))")
            }
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
            }
        case .background:
            isForeground = false
            UIApplication.shared.isIdleTimerDisabled = false
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
            for await samples in mic.utterances {
                await handle(samples)
            }
        }
        Task {
            // His sentences, one at a time through the Egyptian model, in parallel
            // with Whisper working on whatever is said next.
            for await heard in myUtterances {
                await deliverMe(heard)
            }
        }
    }

    // MARK: Pipeline

    private func handle(_ samples: [Float]) async {
        isWorking = true
        defer { isWorking = false }

        let forced: Speaker?
        switch routing {
        case .auto: forced = nil
        case .them: forced = .them
        case .me: forced = .me
        }

        let heard: Heard?
        do {
            heard = try await transcriber.process(samples, forced: forced)
        } catch {
            showStatus("Could not process that sentence. (\(error.localizedDescription))")
            return
        }
        guard let heard else { return }

        switch heard.speaker {
        case .them:
            await deliverThem(heard)
            logMemory("after their sentence")
        case .me:
            myUtterancesContinuation.yield(heard)
        }
    }

    private func deliverThem(_ heard: Heard) async {
        guard ScriptGuard.containsArabic(heard.text) else {
            showTop(english: heard.text, note: nil)
            return
        }
        // Whisper answered (partly) in Arabic instead of translating. Apple's
        // on-device translator is the fallback when its Arabic pack is installed.
        if let english = await translator.toEnglish(heard.text) {
            showTop(english: english, note: "via Apple Translate")
        } else {
            showTop(english: heard.text, note: "part was not translated")
        }
    }

    private func deliverMe(_ heard: Heard) async {
        isComposing = true
        defer { isComposing = false }
        do {
            let rendering = try await romanizer.render(heardEnglish: heard.text)
            showBottom(rendering)
        } catch {
            showBottom(Rendering(
                heardEnglish: heard.text,
                latin: "[could not render this one]",
                gloss: "Say it again, shorter or in other words.",
                source: "error",
                diagnostics: ["error: \(error.localizedDescription)"]
            ))
        }
        logMemory("after my sentence")
    }

    // MARK: Render paths
    // The only three ways text reaches the screen. Each cleans with ScriptGuard
    // (D5) and logs exactly what it shows. The two log-only helpers below them
    // write lines that are never shown, also cleaned.

    private func showTop(english: String, note: String?) {
        let text = ScriptGuard.clean(english)
        let cleanNote = note.map { ScriptGuard.clean($0) }
        guard !text.isEmpty else { return }
        topLines.append(TopLine(english: text, note: cleanNote))
        if topLines.count > maxLinesOnScreen {
            topLines.removeFirst(topLines.count - maxLinesOnScreen)
        }
        log.append("THEM: \(text)" + (cleanNote.map { "  (\($0))" } ?? ""))
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

    private func showStatus(_ message: String) {
        let text = ScriptGuard.clean(message)
        statusMessage = text
        log.append("STATUS: \(text)")
    }

    private func logDiagnostic(_ message: String) {
        log.append("  diag: \(ScriptGuard.clean(message))")
    }

    private func logMemory(_ moment: String) {
        log.append("\(MemoryProbe.line()) (\(moment))")
    }
}
