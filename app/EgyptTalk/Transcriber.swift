import Foundation
import WhisperKit

/// Who an utterance belongs to. `them` fills the top half, `me` the bottom half.
enum Speaker: String, Sendable {
    case them
    case me
}

/// One utterance after Whisper. `text` is raw model output and may still contain
/// Arabic script; it is cleaned only in AppModel's render path (ScriptGuard).
struct Heard: Sendable {
    let speaker: Speaker
    let text: String
}

enum TranscriberError: Error, CustomStringConvertible {
    case notLoaded
    var description: String { "The speech model is not loaded yet." }
}

/// Owns WhisperKit: the one-time model download on home Wi-Fi, loading it from
/// disk afterwards with no network (D9), and turning each utterance into text.
/// An actor so WhisperKit (not Sendable) is only ever touched from one place and
/// its work runs off the main thread.
actor Transcriber {
    /// Full large-v3, compressed by Argmax for iPhone, listed as supported for the
    /// iPhone18 family in argmaxinc/whisperkit-coreml config.json (2026-10-31).
    /// Deliberately NOT large-v3-v20240930 (OpenAI "turbo"): OpenAI's README says
    /// turbo "is not trained for translation tasks" and returns the original
    /// language under --task translate, which would leave the top half empty.
    static let modelVariant = "openai_whisper-large-v3_947MB"
    static let modelRepo = "argmaxinc/whisperkit-coreml"

    /// Remembers, relative to the models folder, where the finished download
    /// lives. Relative because the app container path can change between
    /// installs, and AltStore reinstalls the app every time a new build lands.
    private static let modelPathKey = "whisperModelRelativePath"

    private var pipe: WhisperKit?

    /// Models live in Application Support (not Documents) so they stay out of the
    /// Files app and cannot be deleted by accident there; excluded from iCloud backup.
    static func modelsBase() throws -> URL {
        var base = try FileManager.default
            .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("EgyptTalkModels", isDirectory: true)
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try base.setResourceValues(values)
        return base
    }

    /// The finished model folder on disk, or nil when the download has not completed.
    static func localModelFolder() -> URL? {
        guard let relative = UserDefaults.standard.string(forKey: modelPathKey),
              let base = try? modelsBase() else { return nil }
        let folder = base.appendingPathComponent(relative, isDirectory: true)
        let encoder = folder.appendingPathComponent("AudioEncoder.mlmodelc")
        return FileManager.default.fileExists(atPath: encoder.path) ? folder : nil
    }

    /// Network step, run once at home. Downloads the Core ML model files from
    /// Hugging Face and records where they landed. `progress` gets 0...1.
    func download(progress: @escaping @Sendable (Double) -> Void) async throws {
        let base = try Self.modelsBase()
        let folder = try await WhisperKit.download(
            variant: Self.modelVariant,
            downloadBase: base,
            from: Self.modelRepo,
            progressCallback: { p in progress(p.fractionCompleted) }
        )
        // Hub snapshots land in <base>/models/<repo>/<variant>; the fallback
        // spells that layout out in case the returned path is not under `base`
        // character for character (for example a /private symlink prefix).
        let prefix = base.path + "/"
        let relative = folder.path.hasPrefix(prefix)
            ? String(folder.path.dropFirst(prefix.count))
            : "models/\(Self.modelRepo)/\(folder.lastPathComponent)"
        UserDefaults.standard.set(relative, forKey: Self.modelPathKey)
    }

    /// Loads the downloaded model. The FIRST load also fetches the tokenizer
    /// (openai/whisper-large-v3 tokenizer.json, small) into the models folder and
    /// lets Core ML specialize the model for this chip, which can take minutes;
    /// both are cached, so every later load works with no network.
    func load() async throws {
        guard let folder = Self.localModelFolder() else {
            throw TranscriberError.notLoaded
        }
        let base = try Self.modelsBase()
        let config = WhisperKitConfig(
            downloadBase: base,
            modelFolder: folder.path,
            tokenizerFolder: base,
            verbose: false,
            logLevel: .error,
            prewarm: true,
            load: true,
            download: false
        )
        pipe = try await WhisperKit(config)
    }

    /// One utterance in, one routed result out. `forced` comes from the manual
    /// Them/Me switch (D11); nil means decide from Whisper's language ID.
    /// Returns nil for audio Whisper judges to be non-speech.
    func process(_ samples: [Float], forced: Speaker?) async throws -> Heard? {
        guard let pipe else { throw TranscriberError.notLoaded }

        let speaker: Speaker
        if let forced {
            speaker = forced
        } else {
            // Only two languages are in the room: anything Whisper does not call
            // English is treated as Arabic, so an Egyptian sentence misread as
            // Persian or Urdu still lands in the top half.
            // (detectLangauge is WhisperKit's own spelling.)
            let result = try await pipe.detectLangauge(audioArray: samples)
            speaker = result.language == "en" ? .me : .them
        }

        let options = DecodingOptions(
            task: speaker == .them ? .translate : .transcribe,
            language: speaker == .them ? "ar" : "en",
            temperatureFallbackCount: 3,
            usePrefillPrompt: true,
            detectLanguage: false,
            skipSpecialTokens: true,
            withoutTimestamps: true
        )
        let results = try await pipe.transcribe(audioArray: samples, decodeOptions: options)

        let segments = results.flatMap { $0.segments }
        // Whisper invents text for silence or noise; drop it when every segment
        // says "probably no speech".
        if !segments.isEmpty, segments.allSatisfy({ $0.noSpeechProb > 0.6 }) {
            return nil
        }
        let text = results.map { $0.text }.joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty || Self.isKnownHallucination(text) {
            return nil
        }
        return Heard(speaker: speaker, text: text)
    }

    /// Subtitle credits Whisper learned from video and emits on near-silence.
    private static func isKnownHallucination(_ text: String) -> Bool {
        let lowered = text.lowercased()
        let markers = ["thanks for watching", "subscribe", "amara.org", "nancy qanqar", "subtitles by", "translated by"]
        return markers.contains { lowered.contains($0) }
    }
}
