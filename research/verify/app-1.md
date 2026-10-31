# app-1 verification (2026-10-31)
VERDICT: CLEAN on all nine items, no mismatch found.

1. Rev 1bbc57cb exists (commit) and is tagged v1.1.1 (git tag --points-at; v1.1.1^{commit} equal).
2. Transcriber.swift vs WhisperKit.swift/Configurations.swift at that rev:
   - WhisperKit.download(variant:downloadBase:useBackgroundSession:from:token:endpoint:progressCallback:) async throws -> URL (WhisperKit.swift:253); call at Transcriber:68 uses variant, downloadBase, from, progressCallback in order. ProgressCallback = @Sendable (Progress)->Void (Models.swift:691).
   - WhisperKitConfig.init (Configurations.swift:82): labels downloadBase, modelFolder(String?), tokenizerFolder(URL?), verbose, logLevel, prewarm, load, download all exist, in order. Logging.LogLevel has .error.
   - WhisperKit.init(_ config) async throws (WhisperKit.swift:62).
   - detectLangauge(audioArray:) async throws -> (language: String, langProbs:) (WhisperKit.swift:562), exact spelling.
   - DecodingOptions.init (Configurations.swift:191): task, language, temperatureFallbackCount, usePrefillPrompt, detectLanguage(Bool?), skipSpecialTokens, withoutTimestamps in declared order. DecodingTask has .translate/.transcribe.
   - transcribe(audioArray:decodeOptions:...) async throws -> [TranscriptionResult] (WhisperKit.swift:1033-ish overload); result .text, .segments, segment .noSpeechProb exist (Models.swift:390,448-449).
3. Package.swift (tools 5.10, no unsafeFlags) and Package@swift-6.2.swift (unsafeFlags at line 182, applied to WhisperKit/ArgmaxCore via swiftSettings() default libraryEvolution true). Product "WhisperKit" exists. iOS .v16 in both.
4. HF tree/main contains "path":"openai_whisper-large-v3_947MB" (directory) with AudioEncoder.mlmodelc, MelSpectrogram.mlmodelc, TextDecoder.mlmodelc, config.json, generation_config.json.
5. Apple docs JSON: LanguageAvailability init(), status(from:to:) async -> Status (Locale.Language, Locale.Language?); TranslationSession convenience init(installedSource:target:) iOS 26.0; translate(_ String) async throws -> Response; Response.targetText String; Configuration struct; prepareTranslation() async throws. No MainActor annotation shown. AppleTranslator.swift:18,27,31-32 and ContentView:538,552 match.
6. MicCapture: target format Float32/16000/1ch (130-135), converter + AudioProcessor.resampleBuffer (static throws, AudioProcessor.swift:516) and convertBufferToArray (776); tap removed in close() line 168 and on start failure 159; handled by interruptionNotification and AVAudioEngineConfigurationChange (197-215).
7. Archive path build/EgyptTalk.xcarchive; packaging reads .../Products/Applications/EgyptTalk.app, writes $BUILD_DIR/EgyptTalk.ipa = workspace/build/EgyptTalk.ipa; upload path build/EgyptTalk.ipa same. Triggers workflow_dispatch and push paths app/**. macos-26 listed in runner-images README (arm64: macos-26).
8. (a) TopLine only created in showTop (AppModel:233-237) via ScriptGuard.clean; TheirHalf renders model.topLines (ContentView:288,329,333). (b) MyHalf ContentView:372 heard, 375-376 latin size 34/22 bold, 378 gloss at callout/subheadline. (c) Picker over Routing Auto/Them/Me ContentView:433-437, AppModel:8-11. (d) mic dot + label ContentView:423-426, MicState AppModel:42.
9. No missing await/try, wrong label, missing import, or MainActor violation found.
Note: Package.swift vs 6.2 manifest selection depends on Xcode's Swift (26.x picks 6.2); unsafeFlags rejection for version pins is SwiftPM behaviour not verified from source here.
