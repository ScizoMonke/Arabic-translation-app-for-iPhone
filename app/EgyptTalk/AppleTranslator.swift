import Foundation
import Translation

/// Apple's on-device Translation framework, Arabic to English. Two jobs:
/// the top-half fallback when Whisper answers in Arabic instead of translating,
/// and the gloss engine tomorrow's Romanizer can call to back-translate the
/// Egyptian it produced (D13, D15). Never assumed present: every use checks that
/// the Arabic->English pair is installed on the phone first (D9: offline only).
actor AppleTranslator {
    static let arabic = Locale.Language(identifier: "ar")
    static let english = Locale.Language(identifier: "en")

    private var session: TranslationSession?

    /// .installed means usable offline now; .supported means the pair exists but
    /// must be downloaded (on Wi-Fi, from the setup screen); .unsupported means never.
    func status() async -> LanguageAvailability.Status {
        await LanguageAvailability().status(from: Self.arabic, to: Self.english)
    }

    /// Returns English, or nil when the pair is not installed or translation fails.
    /// The caller decides what to show instead; nothing here touches the UI.
    func toEnglish(_ arabicText: String) async -> String? {
        if session == nil {
            guard await status() == .installed else { return nil }
            // iOS 26 API: a session for an already-installed pair, no SwiftUI needed.
            session = TranslationSession(installedSource: Self.arabic, target: Self.english)
        }
        guard let session else { return nil }
        do {
            let response = try await session.translate(arabicText)
            return response.targetText
        } catch {
            print("AppleTranslator failed: \(error)")
            return nil
        }
    }
}
