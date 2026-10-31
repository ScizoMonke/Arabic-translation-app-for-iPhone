import Foundation

/// D5: no Arabic script is ever shown. This is the ONE place that enforces it.
/// AppModel.showTop / showBottom / showStatus pass every string through `clean`
/// before it is stored for a view or written to the session log, so no other
/// code path can put Arabic letters on screen.
enum ScriptGuard {
    /// Unicode blocks that carry Arabic script (letters, Arabic-Indic digits,
    /// presentation forms, the Arabic letter mark U+061C, Quranic marks).
    private static let arabicRanges: [ClosedRange<UInt32>] = [
        0x0600...0x06FF,   // Arabic
        0x0750...0x077F,   // Arabic Supplement
        0x0870...0x089F,   // Arabic Extended-B
        0x08A0...0x08FF,   // Arabic Extended-A
        0xFB50...0xFDFF,   // Arabic Presentation Forms-A
        0xFE70...0xFEFF,   // Arabic Presentation Forms-B
        0x10E60...0x10E7F, // Rumi Numeral Symbols
        0x10EC0...0x10EFF, // Arabic Extended-C
        0x1EC70...0x1ECBF, // Indic Siyaq Numbers
        0x1ED00...0x1ED4F, // Ottoman Siyaq Numbers
        0x1EE00...0x1EEFF, // Arabic Mathematical Alphabetic Symbols
    ]

    /// Right-to-left marks and embeddings that would otherwise survive stripping
    /// and flip the layout of the remaining Latin text.
    private static let bidiControls: Set<UInt32> = [
        0x200E, 0x200F, 0x202A, 0x202B, 0x202C, 0x202D, 0x202E,
        0x2066, 0x2067, 0x2068, 0x2069,
    ]

    static func isArabic(_ scalar: Unicode.Scalar) -> Bool {
        let v = scalar.value
        return arabicRanges.contains { $0.contains(v) }
    }

    /// True when any Arabic-script code point is present. Used to notice that
    /// Whisper answered in Arabic instead of translating.
    static func containsArabic(_ text: String) -> Bool {
        text.unicodeScalars.contains(where: isArabic)
    }

    /// For the session log only (D23: on a failed answer the log records the raw
    /// model text). Arabic-script code points and bidi controls become \u{XXXX}
    /// escapes, so nothing in the log file renders as Arabic (D5) and the exact
    /// text can still be decoded afterwards; newlines become \n so one answer
    /// stays on one log line.
    static func escapeForLog(_ text: String) -> String {
        var out = ""
        for scalar in text.unicodeScalars {
            if isArabic(scalar) || bidiControls.contains(scalar.value) {
                out += "\\u{" + String(scalar.value, radix: 16, uppercase: true) + "}"
            } else if scalar == "\n" {
                out += "\\n"
            } else if scalar == "\r" {
                continue
            } else {
                out.unicodeScalars.append(scalar)
            }
        }
        return out
    }

    /// Removes Arabic-script code points and bidi controls, then collapses the
    /// whitespace the removal leaves behind.
    static func clean(_ text: String) -> String {
        var kept = String.UnicodeScalarView()
        for scalar in text.unicodeScalars {
            if isArabic(scalar) || bidiControls.contains(scalar.value) {
                kept.append(" ")
            } else {
                kept.append(scalar)
            }
        }
        return String(kept)
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
    }
}
