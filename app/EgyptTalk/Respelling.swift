import Foundation

/// The Latin line the user reads aloud (D20 stage 2). Never written by the model:
/// computed from the model's Arabizi by a fixed digit map, so it is exactly as
/// good as the Arabizi and no worse.
///
/// Mirrors bench/llm/respell.py (the Python twin the bench checked):
///   2 and 3 -> apostrophe, 5 -> kh, 7 -> h, 8 -> gh, 9 -> s, 6 -> t, 4 -> th,
///   everything else kept, lowercased, runs of apostrophes collapsed to one, and an
///   apostrophe at the start of a word dropped (start of text, or after whitespace,
///   a hyphen, "(" or a double quote).
/// The apostrophe is a pause for an English reader: a glottal stop or an ayn cannot
/// be produced from letters, and a short silence there is closer than a guessed vowel.
///   "ma3 el salama" -> "ma' el salama"     "3andi soda3"   -> "andi soda'"
///   "te2olha tany"  -> "te'olha tany"      "el7amdulellah" -> "elhamdulellah"
///   "5alas"         -> "khalas"            "ba3den"        -> "ba'den"
///   "9aba7 el 5eir" -> "sabah el kheir"
enum Respelling {
    private static let digitMap: [Character: String] = [
        "2": "'", "3": "'", "5": "kh", "7": "h", "8": "gh", "9": "s", "6": "t", "4": "th",
    ]

    static func fromArabizi(_ arabizi: String) -> String {
        var mapped = ""
        for ch in arabizi.lowercased() {
            if let replacement = digitMap[ch] {
                mapped += replacement
            } else {
                mapped.append(ch)
            }
        }
        return tidyApostrophes(mapped)
    }

    /// Collapses apostrophe runs, then drops word-initial apostrophes.
    private static func tidyApostrophes(_ text: String) -> String {
        var result = ""
        var previousWasApostrophe = false
        var atWordStart = true
        for ch in text {
            if ch == "'" {
                if previousWasApostrophe || atWordStart { continue }
                previousWasApostrophe = true
                result.append(ch)
                continue
            }
            previousWasApostrophe = false
            result.append(ch)
            atWordStart = ch.isWhitespace || ch == "-" || ch == "(" || ch == "\""
        }
        return result
    }

    // MARK: Rough fallback (D24)

    /// Letter-by-letter Latin for an Arabic-script string, used only when the model
    /// twice failed to give usable Arabizi. One fixed Cairene consonant map, short
    /// vowel marks dropped, no vowel guessing: the result is crude and is always
    /// shown marked as rough. Keys are code points so this file stays ASCII.
    private static let roughMap: [UInt32: String] = [
        0x0621: "'", 0x0622: "a", 0x0623: "a", 0x0624: "'", 0x0625: "e", 0x0626: "'",
        0x0627: "a", 0x0628: "b", 0x0629: "a", 0x062A: "t", 0x062B: "t", 0x062C: "g",
        0x062D: "h", 0x062E: "kh", 0x062F: "d", 0x0630: "z", 0x0631: "r", 0x0632: "z",
        0x0633: "s", 0x0634: "sh", 0x0635: "s", 0x0636: "d", 0x0637: "t", 0x0638: "z",
        0x0639: "'", 0x063A: "gh", 0x0641: "f", 0x0642: "'", 0x0643: "k", 0x0644: "l",
        0x0645: "m", 0x0646: "n", 0x0647: "h", 0x0648: "w", 0x0649: "a", 0x064A: "y",
        0x060C: ",", 0x061B: ";", 0x061F: "?",
        0x0660: "0", 0x0661: "1", 0x0662: "2", 0x0663: "3", 0x0664: "4",
        0x0665: "5", 0x0666: "6", 0x0667: "7", 0x0668: "8", 0x0669: "9",
    ]

    /// Arabic letters through `roughMap`; any other Arabic-block code point
    /// (vowel marks, tatweel, shadda) dropped; everything else kept.
    static func roughFromArabic(_ arabic: String) -> String {
        var mapped = ""
        for scalar in arabic.unicodeScalars {
            if let replacement = roughMap[scalar.value] {
                mapped += replacement
            } else if (0x0600...0x06FF).contains(scalar.value) {
                continue
            } else {
                mapped.unicodeScalars.append(scalar)
            }
        }
        let spaced = mapped.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
        return tidyApostrophes(spaced.lowercased())
    }
}
