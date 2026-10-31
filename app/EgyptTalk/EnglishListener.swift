import AVFoundation
import Foundation
import Speech

/// D35: his English, recognized by Apple's on-device English recognizer while he
/// holds the bottom half. Whisper is kept for the Arabic only.
///
/// SFSpeechRecognizer rather than iOS 26's SpeechAnalyzer: it takes the
/// microphone tap's buffers in their native format with no converter, needs no
/// asset-inventory flow, and its end-of-input call (endAudio) is the release.
/// Every symbol here was read in Apple's documentation JSON on 2026-10-31; none
/// is deprecated on iOS. Recognition must stay on the phone (D9), so
/// `requiresOnDeviceRecognition` is always set and a recognizer that cannot work
/// offline is reported as not ready rather than used over the network.
@MainActor
final class EnglishListener {
    enum Readiness: Equatable {
        case unknown
        case ready
        case notAuthorized
        case onDeviceUnavailable
        case unavailable
    }

    private(set) var readiness: Readiness = .unknown
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))

    /// Asks once for speech recognition permission (the system shows its prompt
    /// only the first time) and checks that English works offline on this phone.
    func prepare() async -> Readiness {
        let status: SFSpeechRecognizerAuthorizationStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { @Sendable status in
                continuation.resume(returning: status)
            }
        }
        if status != .authorized {
            readiness = .notAuthorized
        } else if let recognizer {
            readiness = recognizer.supportsOnDeviceRecognition ? .ready : .onDeviceUnavailable
        } else {
            readiness = .unavailable
        }
        return readiness
    }

    /// One line for the bottom half and the status bar, or nil when ready.
    var problem: String? {
        switch readiness {
        case .ready:
            return nil
        case .unknown:
            return "English recognition is still starting."
        case .notAuthorized:
            return "Speech recognition is off for Egypt Talk. Turn it on in Settings > Apps > Egypt Talk, then reopen the app."
        case .onDeviceUnavailable:
            return "English offline recognition is not on this phone yet. At home on Wi-Fi: Settings > General > Keyboard > Enable Dictation, wait a few minutes for English to download, then reopen the app."
        case .unavailable:
            return "English speech recognition is unavailable on this phone right now."
        }
    }

    /// Touch down: a new recognition for this hold. The returned capture's
    /// `request` receives the audio; `onPartial` gets the growing English on the
    /// main actor. Nil when English recognition cannot run now.
    func begin(onPartial: @escaping @MainActor (String) -> Void) -> EnglishCapture? {
        guard readiness == .ready, let recognizer, recognizer.isAvailable else { return nil }
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.requiresOnDeviceRecognition = true
        request.shouldReportPartialResults = true
        request.addsPunctuation = true
        request.taskHint = .dictation
        let capture = EnglishCapture(request: request, onPartial: onPartial)
        // The result handler's thread is not documented as the main queue (the
        // recognizer's `queue` covers delegates, not this handler), so only plain
        // values cross to the main actor.
        capture.task = recognizer.recognitionTask(with: request) { @Sendable result, error in
            let text = result?.bestTranscription.formattedString
            let isFinal = result?.isFinal ?? false
            let failure = error.map { ($0 as NSError).localizedDescription }
            Task { @MainActor in
                capture.receive(text: text, isFinal: isFinal, failure: failure)
            }
        }
        return capture
    }
}

/// One hold's recognition. Lives on the main actor; only `request` is touched
/// from the audio tap thread (append), which is how Apple's own live-audio
/// sample uses SFSpeechAudioBufferRecognitionRequest.
@MainActor
final class EnglishCapture {
    let request: SFSpeechAudioBufferRecognitionRequest
    fileprivate var task: SFSpeechRecognitionTask?
    private let onPartial: @MainActor (String) -> Void
    /// The newest transcription seen, partial or final.
    private(set) var latest = ""
    /// The recognizer's error text, if it ended with one. Log only.
    private(set) var failure: String?
    private var finished = false
    private var waiter: CheckedContinuation<String, Never>?

    fileprivate init(request: SFSpeechAudioBufferRecognitionRequest, onPartial: @escaping @MainActor (String) -> Void) {
        self.request = request
        self.onPartial = onPartial
    }

    fileprivate func receive(text: String?, isFinal: Bool, failure: String?) {
        guard !finished else { return }
        if let text {
            latest = text
        }
        if isFinal {
            complete()
        } else if let failure {
            self.failure = failure
            complete()
        } else if text != nil {
            onPartial(latest)
        }
    }

    private func complete() {
        guard !finished else { return }
        finished = true
        waiter?.resume(returning: latest)
        waiter = nil
    }

    /// Release: no more audio is coming. Returns the final English, or the last
    /// partial when the recognizer has not finalized within `timeout` (a release
    /// must never hang the bottom half).
    func finish(timeout: Duration) async -> String {
        request.endAudio()
        if finished { return latest }
        return await withCheckedContinuation { continuation in
            waiter = continuation
            Task { @MainActor in
                // Task.sleep throws only on cancellation, and this task is never
                // cancelled; either way the capture must complete.
                try? await Task.sleep(for: timeout)
                if !self.finished {
                    self.failure = self.failure ?? "no final result within \(timeout)"
                    self.task?.cancel()
                    self.complete()
                }
            }
        }
    }

    /// A hold too short to mean anything: stop recognizing, keep nothing.
    func cancel() {
        request.endAudio()
        task?.cancel()
        complete()
    }
}
