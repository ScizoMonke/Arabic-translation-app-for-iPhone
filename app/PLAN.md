# Egypt Talk: build plan (wave app-1, 2026-10-31)

1. Files: project.yml (XcodeGen spec, generates EgyptTalk.xcodeproj on the runner); EgyptTalk/*.swift (App, ContentView, AppModel, ScriptGuard, SessionLog, MicCapture, Transcriber, AppleTranslator, Romanizer); .github/workflows/ios-build.yml; FIRST_RUN.md.
2. Dependencies: one Swift package, argmax-oss-swift (WhisperKit product) pinned by REVISION to tag v1.1.1 = 1bbc57cb7fe6410248a685b1c5a3c6d56adc2ed4. Apple frameworks: SwiftUI, AVFoundation, Translation. No MLX today.
3. Runner: macos-26, Xcode 26.6 (ledger F1), brew install xcodegen, xcodebuild archive -sdk iphoneos with signing off, Payload/ zip to .ipa, upload-artifact.
4. Whisper model: openai_whisper-large-v3_947MB, NOT the v20240930 turbo: OpenAI's README says turbo "is not trained for translation tasks" and returns the original language under --task translate.
5. Routing: per utterance, WhisperKit detectLangauge (sic) -> "en" goes to the bottom half (transcribe, en), anything else goes to the top half (translate, forced ar). Manual Auto/Them/Me switch skips detection.
6. Utterances: own AVAudioEngine tap + energy endpointing (0.8 s hangover, 25 s cap), queued through an AsyncStream to one Transcriber actor.
7. Likely break 1: SwiftPM/Xcode refusing the package because its 6.2 manifest uses unsafeFlags (-enable-library-evolution). Mitigation already in: revision pin (SwiftPM allows unsafe flags for branch/revision deps).
8. Likely break 2: Swift concurrency diagnostics on non-Sendable WhisperKit/TranslationSession. Mitigation: app target in Swift 5 language mode, both held inside actors.
9. Likely break 3: an API name or label I read from source but typed wrong (detectLangauge spelling, WhisperKitConfig/DecodingOptions argument order, TranslationSession(installedSource:target:)). Mitigation: every call checked against the v1.1.1 source and Apple's doc JSON; FIRST_RUN.md lists each with file and line.
10. Out of scope today: the real Romanizer (StubRomanizer stands in), phrasebook, settings, polish.
