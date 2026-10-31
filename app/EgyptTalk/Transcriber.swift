import Foundation
import WhisperKit

enum TranscriberError: LocalizedError {
    case notLoaded
    var errorDescription: String? { "The speech model is not downloaded or not loaded yet." }
}

/// Owns WhisperKit: the one-time model download on home Wi-Fi, loading it from
/// disk afterwards with no network (D9), and turning each utterance of the top
/// half into text. Since D34 everything it hears is Arabic: there is no language
/// detection pass and no English transcription here (his English goes to Apple's
/// recognizer, D35). Returned text is raw model output and may contain Arabic
/// script; it is cleaned only in AppModel's render paths (ScriptGuard).
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

    /// D36: conditioning text for the translate task, given to the decoder as a
    /// previous-context prompt (<|startofprev|> ... before <|startoftranscript|>,
    /// WhisperKit TextDecoder.prefillDecoderInputs at 1bbc57cb). It biases the
    /// decoder towards English output instead of Arabic in Latin letters.
    static let englishPrompt = "The following is an English translation of Egyptian Arabic speech."
    /// The prompt in Whisper tokens, made once at load with the model's own
    /// tokenizer. Nil when the tokenizer is unavailable (translate runs unprompted).
    private var englishPromptTokens: [Int]?

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
    /// Returns a line for the session log about the D36 prompt.
    func load() async throws -> String {
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
        let loaded = try await WhisperKit(config)
        pipe = loaded
        guard let tokenizer = loaded.tokenizer else {
            englishPromptTokens = nil
            return "translate prompt: none (tokenizer unavailable)"
        }
        // Leading space as OpenAI's whisper does for initial_prompt. Special
        // tokens the tokenizer may add are dropped here; WhisperKit drops them
        // too, this only keeps the logged count honest.
        let tokens = tokenizer.encode(text: " " + Self.englishPrompt)
            .filter { $0 < tokenizer.specialTokens.specialTokenBegin }
        englishPromptTokens = tokens.isEmpty ? nil : tokens
        return "translate prompt: \(tokens.count) tokens"
    }

    /// The top half's first pass: Arabic speech to English with the D36 prompt.
    /// Nil for audio Whisper judges to be non-speech.
    func translate(_ samples: [Float]) async throws -> String? {
        try await decode(samples, task: .translate, promptTokens: englishPromptTokens)
    }

    /// The D36 fallback pass: the same audio written down in Arabic, for Apple
    /// Translation. Unprompted: an English prompt would pull it towards English.
    func transcribeArabic(_ samples: [Float]) async throws -> String? {
        try await decode(samples, task: .transcribe, promptTokens: nil)
    }

    /// Source language is always forced to Arabic (D34: the top half hears
    /// only the people around him).
    private func decode(_ samples: [Float], task: DecodingTask, promptTokens: [Int]?) async throws -> String? {
        guard let pipe else { throw TranscriberError.notLoaded }
        let options = DecodingOptions(
            task: task,
            language: "ar",
            temperatureFallbackCount: 3,
            usePrefillPrompt: true,
            detectLanguage: false,
            skipSpecialTokens: true,
            withoutTimestamps: true,
            promptTokens: promptTokens
        )
        let results = try await pipe.transcribe(audioArray: samples, decodeOptions: options)

        let segments = results.flatMap { $0.segments }
        // Whisper invents text for silence or noise; drop it when every segment
        // says "probably no speech".
        if !segments.isEmpty, segments.allSatisfy({ $0.noSpeechProb > 0.6 }) {
            return nil
        }
        let text = Self.stripLeadingJunk(results.map { $0.text }.joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines))
        if text.isEmpty || Self.isKnownHallucination(text) {
            return nil
        }
        return text
    }

    /// On the PC bench (bench/asr, clip r0000) the translate task opened a clean
    /// show intro with "F**k". Whisper does this on the first word after noise;
    /// the rest of the sentence was right, so only a leading expletive is dropped.
    private static func stripLeadingJunk(_ text: String) -> String {
        let junk: Set<String> = ["f**k", "fuck", "f*ck", "fucking", "shit", "damn"]
        var words = text.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
        while let first = words.first,
              junk.contains(first.lowercased().trimmingCharacters(in: .punctuationCharacters)) {
            words.removeFirst()
        }
        return words.joined(separator: " ")
    }

    /// Subtitle credits Whisper learned from video and emits on near-silence.
    private static func isKnownHallucination(_ text: String) -> Bool {
        let lowered = text.lowercased()
        // The last marker is the D36 prompt itself: on near-silence a prompted
        // Whisper can repeat its prompt back.
        let markers = ["thanks for watching", "subscribe", "amara.org", "nancy qanqar", "subtitles by", "translated by",
                       "english translation of egyptian arabic"]
        return markers.contains { lowered.contains($0) }
    }
}
