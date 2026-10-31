import Foundation
import WhisperKit

enum TranscriberError: LocalizedError {
    case notLoaded
    var errorDescription: String? { "The speech model is not downloaded or not loaded yet." }
}

/// The two Whisper models kept on the phone (D43). Both are downloaded at
/// setup; only one is ever loaded (R10).
enum SpeechModel: Sendable, CaseIterable {
    /// OpenAI's large-v3 turbo: transcribes Arabic for the live top half.
    /// It cannot translate (OpenAI's README: "not trained for translation
    /// tasks"), so the English comes from Apple Translation.
    case live
    /// Full large-v3, today's path: Whisper translates each utterance. Used
    /// when Apple's Arabic pack is missing, and as the live model on a slower
    /// cadence when turbo refuses to load (R31).
    case full

    var variant: String {
        switch self {
        case .live: return Transcriber.liveVariant
        case .full: return "openai_whisper-large-v3_947MB"
        }
    }

    /// For the setup screen. Sizes are the Hugging Face folder totals read on
    /// 2026-10-31 (646 MB, 948 MB; full turbo 1,638 MB).
    var sizeLabel: String {
        switch self {
        case .live: return Transcriber.liveVariant.hasSuffix("_632MB") ? "about 650 MB" : "about 1.6 GB"
        case .full: return "about 950 MB"
        }
    }

    /// Where the finished download is remembered. The full model keeps the
    /// key app-1 to app-4 used, so the copy already on the phone is reused.
    /// The live key carries the variant, so changing `liveVariant` downloads
    /// the new one instead of loading the old folder under a new name.
    var pathKey: String {
        switch self {
        case .live: return "whisperModelRelativePath." + Transcriber.liveVariant
        case .full: return "whisperModelRelativePath"
        }
    }
}

/// One stretch of Arabic as Whisper heard it, with times in seconds from the
/// start of the audio that was decoded. Raw model text: may contain Arabic
/// script, cleaned only in AppModel's render paths (ScriptGuard).
struct HeardSegment: Sendable, Equatable {
    let text: String
    let start: Float
    let end: Float
}

/// Owns WhisperKit: the one-time downloads on home Wi-Fi, loading from disk
/// afterwards with no network (D9), and decoding the top half's audio.
/// Everything it hears is Arabic (D34): no language detection, no English
/// transcription here (his English goes to Apple's recognizer, D35).
/// An actor so WhisperKit (not Sendable) is only ever touched from one place and
/// its work runs off the main thread.
actor Transcriber {
    /// D43: OpenAI's turbo (large-v3-v20240930), Argmax's compressed build.
    /// Listed for the iPhone18 identifiers (the iPhone 17 family) in
    /// argmaxinc/whisperkit-coreml config.json, read 2026-10-31. The full,
    /// uncompressed turbo is "openai_whisper-large-v3-v20240930_turbo"
    /// (1.6 GB, NOT in that table); changing this one constant selects it.
    /// Memory would allow it (field log 2026-10-31: headroom never below
    /// 2.7 GB with large-v3 and the 4B model loaded); the compressed one stays
    /// the default because it is the one Argmax lists for this phone.
    /// Naming trap: "openai_whisper-large-v3_turbo" is Argmax's build of
    /// large-v3, not OpenAI's turbo model.
    static let liveVariant = "openai_whisper-large-v3-v20240930_turbo_632MB"
    static let modelRepo = "argmaxinc/whisperkit-coreml"

    /// WhisperKit decodes nothing from audio shorter than its windowClipTime
    /// (1.0 s by default, TranscribeTask at 1bbc57cb). Shorter audio is padded
    /// with silence to this length; Whisper pads every window to 30 s with
    /// zeros anyway, so the padding adds nothing it would not see.
    static let minimumDecodeSeconds: Float = 1.2

    private var pipe: WhisperKit?

    /// D36, now only on today's path (pack missing): conditioning text for the
    /// translate task, given to the decoder as a previous-context prompt
    /// (<|startofprev|> ... before <|startoftranscript|>, WhisperKit
    /// TextDecoder.prefillDecoderInputs at 1bbc57cb). It biases the decoder
    /// towards English output instead of Arabic in Latin letters.
    static let englishPrompt = "The following is an English translation of Egyptian Arabic speech."
    /// The prompt in Whisper tokens, made at load with the model's own
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

    /// The finished model folder on disk, or nil when that download has not completed.
    static func localModelFolder(_ model: SpeechModel) -> URL? {
        guard let relative = UserDefaults.standard.string(forKey: model.pathKey),
              let base = try? modelsBase() else { return nil }
        let folder = base.appendingPathComponent(relative, isDirectory: true)
        let encoder = folder.appendingPathComponent("AudioEncoder.mlmodelc")
        return FileManager.default.fileExists(atPath: encoder.path) ? folder : nil
    }

    /// Network step, run once at home. Downloads one model's Core ML files from
    /// Hugging Face and records where they landed. `progress` gets 0...1.
    func download(_ model: SpeechModel, progress: @escaping @Sendable (Double) -> Void) async throws {
        let base = try Self.modelsBase()
        let folder = try await WhisperKit.download(
            variant: model.variant,
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
        UserDefaults.standard.set(relative, forKey: model.pathKey)
    }

    /// Loads one downloaded model, unloading whatever was loaded before. The
    /// FIRST load fetches the tokenizer (openai/whisper-large-v3 tokenizer.json,
    /// small; WhisperKit picks it from the model's dimensions, which turbo
    /// shares with large-v3, so both models use the same cached file) and lets
    /// Core ML specialize the model for this chip, which can take minutes; both
    /// are cached, so later loads need no network.
    /// Returns a line for the session log: variant, load seconds, prompt.
    func load(_ model: SpeechModel) async throws -> String {
        guard let folder = Self.localModelFolder(model) else {
            throw TranscriberError.notLoaded
        }
        if let previous = pipe {
            await previous.unloadModels()
            pipe = nil
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
        let started = Date()
        let whisper = try await WhisperKit(config)
        let seconds = Date().timeIntervalSince(started)
        pipe = whisper
        let timing = "\(model.variant) loaded in \(String(format: "%.1f", seconds)) s"
        guard let tokenizer = whisper.tokenizer else {
            englishPromptTokens = nil
            return "\(timing); translate prompt: none (tokenizer unavailable)"
        }
        // Leading space as OpenAI's whisper does for initial_prompt. Special
        // tokens the tokenizer may add are dropped here; WhisperKit drops them
        // too, this only keeps the logged count honest.
        let tokens = tokenizer.encode(text: " " + Self.englishPrompt)
            .filter { $0 < tokenizer.specialTokens.specialTokenBegin }
        englishPromptTokens = tokens.isEmpty ? nil : tokens
        return "\(timing); translate prompt: \(tokens.count) tokens"
    }

    /// Today's path (Apple pack missing): Arabic speech to English with the D36
    /// prompt. Nil for audio Whisper judges to be non-speech.
    func translate(_ samples: [Float]) async throws -> String? {
        guard let pipe else { throw TranscriberError.notLoaded }
        let options = DecodingOptions(
            task: .translate,
            language: "ar",
            temperatureFallbackCount: 3,
            usePrefillPrompt: true,
            detectLanguage: false,
            skipSpecialTokens: true,
            withoutTimestamps: true,
            promptTokens: englishPromptTokens
        )
        let results = try await pipe.transcribe(audioArray: samples, decodeOptions: options)
        let segments = results.flatMap { $0.segments }
        if Self.isProbablySilence(segments) {
            return nil
        }
        let text = Self.stripLeadingJunk(results.map { $0.text }.joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines))
        if !Self.isText(text) || Self.isKnownHallucination(text) {
            return nil
        }
        return text
    }

    /// D43 live path: the Arabic written down, split where Whisper puts its
    /// timestamps, times relative to the start of `samples`. Known
    /// hallucinations and letterless segments are dropped here, before any
    /// translation. Empty for audio Whisper judges to be non-speech.
    func transcribeSegments(_ samples: [Float]) async throws -> [HeardSegment] {
        guard let pipe else { throw TranscriberError.notLoaded }
        var audio = samples
        let minimum = Int(Self.minimumDecodeSeconds * Float(WhisperKit.sampleRate))
        if audio.count < minimum {
            audio += [Float](repeating: 0, count: minimum - audio.count)
        }
        let options = DecodingOptions(
            task: .transcribe,
            language: "ar",
            // One retry at a higher temperature at most: a decode runs every
            // second, and the next one gets another chance anyway.
            temperatureFallbackCount: 1,
            usePrefillPrompt: true,
            detectLanguage: false,
            skipSpecialTokens: true,
            // Timestamps on: they are where the window may be cut.
            withoutTimestamps: false
        )
        let results = try await pipe.transcribe(audioArray: audio, decodeOptions: options)
        let segments = results.flatMap { $0.segments }
        if Self.isProbablySilence(segments) {
            return []
        }
        return segments.compactMap { segment in
            let text = segment.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard Self.isText(text), !Self.isKnownHallucination(text) else { return nil }
            return HeardSegment(text: text, start: segment.start, end: segment.end)
        }
    }

    /// Whisper invents text for silence or noise; drop it when every segment
    /// says "probably no speech".
    private static func isProbablySilence(_ segments: [TranscriptionSegment]) -> Bool {
        !segments.isEmpty && segments.allSatisfy { $0.noSpeechProb > 0.6 }
    }

    /// A segment that is only punctuation, digits' separators or a dash is not
    /// a segment (field log 2026-10-31: raw "-" came back three times).
    static func isText(_ text: String) -> Bool {
        text.contains { $0.isLetter }
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

    /// Subtitle credits and channel boilerplate Whisper learned from video and
    /// emits on near-silence. Checked on Whisper's Arabic before translation
    /// (live path), and on every English line before it is shown (all paths;
    /// field log 2026-10-31: "subscribe to the channel" reached the screen
    /// through a path that skipped this check).
    static func isKnownHallucination(_ text: String) -> Bool {
        let lowered = text.lowercased()
        // The last English marker is the D36 prompt itself: on near-silence a
        // prompted Whisper can repeat its prompt back.
        let markers = ["thanks for watching", "subscribe", "amara.org", "nancy qanqar", "subtitles by", "translated by",
                       "english translation of egyptian arabic",
                       // Arabic forms, matched on the transcribe output:
                       "نانسي قنقر",          // "Nancy Qanqar" (as in "translation by Nancy Qanqar")
                       "اشتركوا في القناة",   // "subscribe to the channel"
                       "اشترك في القناة",     // "subscribe to the channel" (singular)
                       "شكرا للمشاهدة",       // "thanks for watching"
                       "شكرا على المشاهدة"]   // "thanks for watching"
        return markers.contains { lowered.contains($0) }
    }
}
