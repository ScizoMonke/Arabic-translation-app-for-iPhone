import Foundation

/// What the bottom half shows for one thing the user said (D13).
struct Rendering: Sendable {
    /// The English the phone heard him say.
    let heardEnglish: String
    /// The Egyptian Arabic to say, in Latin letters (D10 respelling). Shown largest.
    let latin: String
    /// A literal English gloss of that Egyptian, so he knows what he is saying.
    let gloss: String
}

/// The bottom-half engine. Tomorrow's on-device model (MLX Swift, Qwen or Gemma
/// architecture) implements this same protocol and replaces StubRomanizer in
/// AppModel; nothing else changes. Heavy implementations should be actors so
/// their work stays off the main thread.
protocol Romanizer {
    func render(heardEnglish: String) async throws -> Rendering
}

/// Placeholder until the bench picks a model. Output is marked so it can never be
/// mistaken for a real rendering.
struct StubRomanizer: Romanizer {
    func render(heardEnglish: String) async throws -> Rendering {
        Rendering(
            heardEnglish: heardEnglish,
            latin: "[STUB] Egyptian in Latin letters goes here",
            gloss: "[STUB] literal meaning goes here"
        )
    }
}
