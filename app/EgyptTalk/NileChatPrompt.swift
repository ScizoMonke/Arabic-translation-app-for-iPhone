import Foundation

/// The whole instruction Nile-Chat-4B receives, in one constant (D20, D24).
/// Source: the bench's prompt C, verbatim (bench/llm/runs/Nile-Chat-4B-promptC-rp1.15/
/// meta.json, system_prompt), with the two D24 rules inserted before the examples.
/// To swap in a new text from the bench, replace the body of `instruction` only;
/// it is a raw string, so quotes and Arabic need no escaping. Keep it free of
/// triple quotes. This text never reaches a view or the log.
enum NileChatPrompt {
    static let instruction = #"""
You translate what an English-speaking visitor says to his Egyptian family into Egyptian Arabic.
Use Egyptian Cairo colloquial Arabic (Masri) as spoken at home in Cairo. Never use Modern Standard Arabic (Fusha); never use Levantine or Gulf forms.

For the English sentence you are given, reply with ONLY one JSON object, no other text, with exactly these two string fields:
- "arabic": the Egyptian colloquial sentence in Arabic script.
- "arabizi": the same Egyptian sentence in Arabizi (Franco-Arabic), the way Egyptians text: 2 for the glottal stop (hamza, and qaf as Cairenes say it), 3 for ayn, 7 for the emphatic h, 5 for kh, 9 for emphatic s where used, gh for ghayn. Latin letters and digits only, never Arabic script.

Rules:
- The speaker is a man talking to his own family, so every first-person form is masculine.
- The arabizi field contains only Latin letters, digits, spaces and basic punctuation. Never put Arabic script in it.

Examples.
English: "The car is outside."
{"arabic": "العربية برة", "arabizi": "el 3arabeyya barra"}
English: "My phone is dead."
{"arabic": "موبايلي فاصل شحن", "arabizi": "mobayli fasel sha7n"}
"""#

    /// D37: the part of every rendered prompt that never changes, which
    /// LlamaEngine processes once at load and keeps in its KV cache. The cut is
    /// after the blank line that closes the folded system text, just before
    /// `English: "`: everything up to there is fixed, everything after depends
    /// on the sentence. The cut does not have to land on a token boundary for
    /// correctness: LlamaEngine tokenizes each full prompt exactly as before and
    /// reuses only the leading tokens it shares with the cache.
    static let fixedPrefix = "<start_of_turn>user\n" + instruction + "\n\n"

    /// Gemma 3 has no system role. The GGUF's own chat template
    /// (tokenizer.chat_template, read from the file header 2026-10-31) folds a
    /// system message into the first user turn as `system + "\n\n"` and trims the
    /// user content; this reproduces that rendering exactly as the bench saw it,
    /// minus the leading <bos>, which LlamaEngine prepends as a token because the
    /// GGUF sets add_bos_token = False. The text is the same, character for
    /// character, as before D37; only its first part is now named.
    static func render(english: String) -> String {
        let sentence = english.trimmingCharacters(in: .whitespacesAndNewlines)
        return fixedPrefix + "English: \"" + sentence + "\"<end_of_turn>\n<start_of_turn>model\n"
    }
}
