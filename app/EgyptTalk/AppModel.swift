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

/// One card in the bottom half (D13): what he said, what to say, what it means.
struct BottomLine: Identifiable {
    let id = UUID()
    let heard: String
    let latin: String
    let gloss: String
}

@MainActor
final class AppModel: ObservableObject {
    enum Phase: Equatable {
        case checking
        case needsDownload
        case downloading(Double)
        case preparing
        case ready
        case failed(String)
    }

    @Published private(set) var phase: Phase = .checking
    @Published private(set) var micState: MicState = .off
    @Published private(set) var isWorking = false
    @Published var routing: Routing = .auto
    @Published private(set) var topLines: [TopLine] = []
    @Published private(set) var bottomLines: [BottomLine] = []
    @Published private(set) var statusMessage: String?
    @Published private(set) var translationStatus: LanguageAvailability.Status?

    private let transcriber = Transcriber()
    private let translator = AppleTranslator()
    /// Swap point for tomorrow's model: replace StubRomanizer() with the real one.
    private let romanizer: any Romanizer = StubRomanizer()
    private let log = SessionLog()
    private let mic = MicCapture()
    private var pipelineStarted = false
    private var isForeground = true

    /// Keeps the views fast over a long day; the session log keeps everything.
    private let maxLinesOnScreen = 300

    // MARK: Setup

    func launch() async {
        await refreshTranslationStatus()
        guard phase == .checking else { return }
        if Transcriber.localModelFolder() == nil {
            phase = .needsDownload
        } else {
            await prepareModel()
        }
    }

    func downloadModel() async {
        phase = .downloading(0)
        do {
            try await transcriber.download { fraction in
                Task { @MainActor in
                    // Progress callbacks can arrive after the download returned;
                    // only a phase that is still downloading may be updated.
                    if case .downloading = self.phase {
                        self.phase = .downloading(fraction)
                    }
                }
            }
        } catch {
            phase = .failed("Download failed. Check Wi-Fi and try again. (\(error.localizedDescription))")
            return
        }
        await prepareModel()
    }

    func retry() async {
        phase = .checking
        await launch()
    }

    private func prepareModel() async {
        phase = .preparing
        do {
            try await transcriber.load()
        } catch {
            phase = .failed("Could not load the speech model. (\(error.localizedDescription))")
            return
        }
        phase = .ready
        showStatus("Ready. Model: \(Transcriber.modelVariant)")
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
            // One utterance at a time; the stream buffers while Whisper is busy.
            for await samples in mic.utterances {
                await handle(samples)
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
        case .me:
            await deliverMe(heard)
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
        do {
            let rendering = try await romanizer.render(heardEnglish: heard.text)
            showBottom(rendering)
        } catch {
            showBottom(Rendering(
                heardEnglish: heard.text,
                latin: "[could not render this one]",
                gloss: error.localizedDescription
            ))
        }
    }

    // MARK: Render paths
    // The only three ways text reaches the screen. Each cleans with ScriptGuard
    // (D5) and logs exactly what it shows.

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
            gloss: ScriptGuard.clean(rendering.gloss)
        )
        bottomLines.append(line)
        if bottomLines.count > maxLinesOnScreen {
            bottomLines.removeFirst(bottomLines.count - maxLinesOnScreen)
        }
        log.append("ME: heard \"\(line.heard)\" | say \"\(line.latin)\" | means \"\(line.gloss)\"")
    }

    private func showStatus(_ message: String) {
        let text = ScriptGuard.clean(message)
        statusMessage = text
        log.append("STATUS: \(text)")
    }
}
