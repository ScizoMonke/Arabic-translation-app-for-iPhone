import Foundation
import Translation

/// Apple's on-device Translation framework, Arabic to English. Two jobs: the
/// English of the live top half (D43: every settled Arabic segment and the
/// still-changing tail), and the gloss under each Egyptian sentence in the
/// bottom half (D13, D20). Never assumed present: every use checks that the
/// Arabic->English pair is installed on the phone first (D9: offline only).
actor AppleTranslator {
    static let arabic = Locale.Language(identifier: "ar")
    static let english = Locale.Language(identifier: "en")

    private var session: TranslationSession?
    /// R24: the request before this one. Each request waits for it, so Apple's
    /// session only ever sees one request at a time, in the order they were
    /// made. (An actor alone does not do that: it lets the next caller in
    /// while the current one awaits Apple.)
    private var previous: Task<String?, Never>?

    /// .installed means usable offline now; .supported means the pair exists but
    /// must be downloaded (on Wi-Fi, from the setup screen); .unsupported means never.
    func status() async -> LanguageAvailability.Status {
        await LanguageAvailability().status(from: Self.arabic, to: Self.english)
    }

    /// Returns English, or nil when the pair is not installed or translation fails.
    /// The caller decides what to show instead; nothing here touches the UI.
    func toEnglish(_ arabicText: String) async -> String? {
        let before = previous
        let request = Task<String?, Never> {
            _ = await before?.value
            return await self.translateNow(arabicText)
        }
        previous = request
        return await request.value
    }

    private func translateNow(_ arabicText: String) async -> String? {
        guard !arabicText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
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
