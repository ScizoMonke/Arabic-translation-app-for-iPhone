import Foundation
import Translation

/// What the bottom half shows for one thing the user said (D13, D20).
struct Rendering: Sendable {
    /// The English the phone heard him say.
    let heardEnglish: String
    /// The Egyptian to say, in plain Latin letters. Shown largest.
    let latin: String
    /// The meaning check, as one display line: "Means: ..." from Apple Translation
    /// or a vetted phrasebook gloss, or a line saying the check is unavailable.
    /// Never the model's own words (D13, D20).
    let gloss: String
    /// Small tag naming where `latin` came from: phrasebook or model.
    let source: String
    /// Log-only lines (timings, rejection reasons, escaped raw text). Never shown.
    let diagnostics: [String]
}

/// The bottom-half engine. AppModel calls it one sentence at a time.
protocol Romanizer {
    func render(heardEnglish: String) async throws -> Rendering
}

/// D20 + D22 + D23 + D24: phrasebook first; otherwise Nile-Chat-4B for Arabic
/// script + Arabizi, the Latin line computed from the Arabizi (Respelling), and the
/// meaning check from Apple's Arabic-to-English translation of the Arabic script.
actor EgyptianRomanizer: Romanizer {
    /// D23: answers are about 25-50 tokens; 120 leaves room without letting a
    /// runaway answer cost more than a few seconds.
    static let maxNewTokens = 120

    private let engine = LlamaEngine()
    private let translator: AppleTranslator
    private var phrasebook: Phrasebook?
    private var modelLoaded = false

    init(translator: AppleTranslator) {
        self.translator = translator
    }

    func installPhrasebook(_ book: Phrasebook?) {
        phrasebook = book
    }

    /// Returns a description line for the session log.
    func loadModel(path: String) async throws -> String {
        let description = try await engine.load(path: path)
        modelLoaded = true
        return description
    }

    func render(heardEnglish: String) async throws -> Rendering {
        if let match = phrasebook?.match(heardEnglish) {
            let source = match.isExact
                ? "phrasebook"
                : "phrasebook, close to \"\(match.alias)\""
            return Rendering(
                heardEnglish: heardEnglish,
                latin: match.entry.respelling,
                gloss: "Means: " + match.entry.gloss,
                source: source,
                diagnostics: ["phrasebook \(match.entry.id), similarity \(Self.twoDecimals(match.similarity))"]
            )
        }

        guard modelLoaded else {
            return Rendering(
                heardEnglish: heardEnglish,
                latin: "[the Egyptian model is not loaded]",
                gloss: "Finish setup at home on Wi-Fi, then reopen the app.",
                source: "model missing",
                diagnostics: []
            )
        }

        let prompt = NileChatPrompt.render(english: heardEnglish)
        var diagnostics: [String] = []
        var roughSource: String?   // an Arabic field that failed validation but has letters

        // D23/D24: greedy once; on a loop, a parse failure or a failed validation,
        // one retry with mild sampling.
        for sampling in [Sampling.greedy, Sampling.mild] {
            let generation = try await engine.generate(
                prompt: prompt, maxNewTokens: Self.maxNewTokens, sampling: sampling)
            diagnostics.append(
                "model \(sampling.label): \(generation.promptTokens) prompt + \(generation.newTokens) new tokens, "
                + "\(Self.twoDecimals(generation.seconds)) s, stop: \(generation.stop.rawValue)")

            switch Self.check(generation) {
            case .usable(let arabic, let arabizi):
                let gloss = await glossLine(forArabic: arabic)
                return Rendering(
                    heardEnglish: heardEnglish,
                    latin: Respelling.fromArabizi(arabizi),
                    gloss: gloss,
                    source: sampling == .greedy ? "model" : "model, second try",
                    diagnostics: diagnostics
                )
            case .rejected(let reason, let arabic):
                diagnostics.append("rejected (\(reason)); raw: \(ScriptGuard.escapeForLog(generation.text))")
                if let arabic, ScriptGuard.containsArabic(arabic) {
                    roughSource = arabic
                }
            }
        }

        if let arabic = roughSource {
            let rough = Respelling.roughFromArabic(arabic)
            if !rough.isEmpty {
                let gloss = await glossLine(forArabic: arabic)
                return Rendering(
                    heardEnglish: heardEnglish,
                    latin: rough,
                    gloss: gloss,
                    source: "model, ROUGH: letters only, vowels missing",
                    diagnostics: diagnostics
                )
            }
        }
        return Rendering(
            heardEnglish: heardEnglish,
            latin: "[the model could not answer this one]",
            gloss: "Say it again, shorter or in other words.",
            source: "model failed",
            diagnostics: diagnostics
        )
    }

    /// The meaning check (D13, D20 stage 3). Apple Translation only.
    private func glossLine(forArabic arabic: String) async -> String {
        if let english = await translator.toEnglish(arabic) {
            let trimmed = english.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return "Means: " + trimmed
            }
        }
        if await translator.status() != .installed {
            return "Meaning check unavailable: the Apple Arabic pack is not installed. Tap the gear in the middle bar and download it at home on Wi-Fi."
        }
        return "Meaning check failed for this one. Do not rely on it."
    }

    private static func twoDecimals(_ value: Double) -> String {
        String(format: "%.2f", value)
    }

    // MARK: Parsing and validation (pure)

    enum Verdict {
        case usable(arabic: String, arabizi: String)
        case rejected(reason: String, arabic: String?)
    }

    /// Tolerates a code fence or prose around the object: takes the first
    /// top-level {...} span, parses it as JSON, requires both fields as non-empty
    /// strings, then applies the D24 script checks.
    static func check(_ generation: Generation) -> Verdict {
        if generation.stop == .loop {
            return .rejected(reason: "loop guard", arabic: nil)
        }
        guard let objectText = firstJSONObject(in: generation.text),
              let data = objectText.data(using: .utf8),
              let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        else {
            return .rejected(reason: "no JSON object", arabic: nil)
        }
        let arabic = (object["arabic"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let arabizi = (object["arabizi"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !arabic.isEmpty, !arabizi.isEmpty else {
            return .rejected(reason: "missing field", arabic: arabic.isEmpty ? nil : arabic)
        }
        guard ScriptGuard.containsArabic(arabic) else {
            return .rejected(reason: "arabic field has no Arabic letters", arabic: nil)
        }
        guard !containsLatinLetter(arabic) else {
            return .rejected(reason: "Latin letters in the arabic field", arabic: arabic)
        }
        guard !ScriptGuard.containsArabic(arabizi) else {
            return .rejected(reason: "Arabic script in the arabizi field", arabic: arabic)
        }
        guard containsLatinLetter(arabizi) else {
            return .rejected(reason: "arabizi field has no Latin letters", arabic: arabic)
        }
        return .usable(arabic: arabic, arabizi: arabizi)
    }

    private static func containsLatinLetter(_ text: String) -> Bool {
        text.unicodeScalars.contains { ($0.value >= 0x41 && $0.value <= 0x5A) || ($0.value >= 0x61 && $0.value <= 0x7A) }
    }

    /// The first balanced top-level {...} span, string-aware, or nil.
    static func firstJSONObject(in text: String) -> String? {
        let bytes = Array(text.utf8)
        guard let start = bytes.firstIndex(of: 0x7B) else { return nil }
        var depth = 0
        var inString = false
        var escaped = false
        for i in start..<bytes.count {
            let b = bytes[i]
            if inString {
                if escaped { escaped = false }
                else if b == 0x5C { escaped = true }
                else if b == 0x22 { inString = false }
                continue
            }
            if b == 0x22 { inString = true }
            else if b == 0x7B { depth += 1 }
            else if b == 0x7D {
                depth -= 1
                if depth == 0 {
                    return String(decoding: bytes[start...i], as: UTF8.self)
                }
            }
        }
        return nil
    }
}
