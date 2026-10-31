# Account: wave app-1 (2026-10-31)

Overflow from the return. What was decided, on what evidence, and what is open.

## Decisions taken in this wave

1. **Whisper variant: `openai_whisper-large-v3_947MB`, not the v20240930 turbo.**
   Raw evidence: openai/whisper README (main, read 2026-10-31): "the `turbo` model
   is not trained for translation tasks" and "The `turbo` model will return the
   original language even if `--task translate` is specified." Argmax's
   `large-v3-v20240930*` folders are that turbo model. Argmax README table also
   labels the uncompressed `large-v3-v20240930_turbo` (1,638 MB on Hugging Face)
   "Recommended on macOS", and `config.json` in argmaxinc/whisperkit-coreml lists,
   for identifiers iPhone15..iPhone18, only the compressed variants:
   `large-v3_947MB`, `large-v3_turbo_954MB`, distil 594/600MB,
   `large-v3-v20240930_626MB`, `large-v3-v20240930_turbo_632MB`. The full
   large-v3 at 947 MB is the only supported translate-capable large model.
   Cost: a 32-layer decoder instead of turbo's 4 layers, so slower per token.
   Affects: D16 (top half), R10 (memory: about 1 GB of Whisper weights), and the
   parallel bench, which should measure large-v3, not turbo, for translate.
   Swap point: `Transcriber.modelVariant`.
2. **Routing (D11): Whisper language ID per utterance, then a second decode.**
   `detectLangauge(audioArray:)` (WhisperKit's spelling) returns one language.
   "en" goes to the bottom half (task transcribe, language en); anything else goes
   to the top half (task translate, language forced to "ar"). Forcing "ar" means an
   Egyptian sentence misdetected as Persian or Urdu is still translated as Arabic.
   The manual Auto/Them/Me switch skips detection. Not chosen: SFSpeechRecognizer
   in parallel (a second mic consumer and a second model for one bit of
   information); a single pass with detectLanguage plus translate (it would decode
   English audio under `<|en|><|translate|>`, an untrained combination).
   Limitation seen in source: `langProbs` holds only the sampled language, not a
   distribution, and the language logits filter is private, so detection cannot be
   restricted to {en, ar}.
3. **Package pin by revision** `1bbc57cb7fe6410248a685b1c5a3c6d56adc2ed4` (tag v1.1.1,
   2026-10-08) at github.com/argmaxinc/argmax-oss-swift. Why a revision: the
   package's `Package@swift-6.2.swift` (selected by Xcode 26's Swift 6.2+) gives the
   WhisperKit and ArgmaxCore targets `.unsafeFlags(["-enable-library-evolution", ...])`
   (also in v1.0.0 and v1.1.0). SwiftPM release/6.2 `ModulesGraph+Loading.swift`
   calls `diagnoseInvalidUseOfUnsafeFlags` unless the package is in
   `unsafeAllowedPackages`, which `Workspace+Manifests.swift` fills with
   branch- or revision-based checkouts. v0.15.0 has no unsafe flags (fallback).
4. **Project generator: XcodeGen** (2.46.0, released 2026-07-16), installed by brew on
   the runner (not on the macos-26 image per its raw readme). No pbxproj written here.
5. **iOS target 26.0**, iPhone only, portrait. Lets `TranslationSession(installedSource:target:)`
   (iOS 26.0 per Apple doc JSON) be used with no availability check on the API;
   the language pack itself is checked at runtime.
6. **Swift 5 language mode** for the app target, so non-Sendable crossings are
   warnings. WhisperKit and TranslationSession live inside actors.
7. **Own mic capture** (AVAudioEngine tap + energy endpointing: 0.8 s hangover,
   0.3 s pre-roll, 25 s cap, 0.35 s minimum speech) instead of WhisperKit's
   `AudioProcessor.startRecordingLive`, whose `audioSamples` buffer grows without
   bound and is purged unsynchronised with the audio thread. WhisperKit's own static
   resampler is reused.
8. **Offline path**: download once with `WhisperKit.download` into Application
   Support/EgyptTalkModels (excluded from backup, hidden from Files); the relative
   path is stored in UserDefaults only after the download returns. Every launch
   loads from that folder with `download: false`. The tokenizer is fetched on the
   first load (still on Wi-Fi) into the same base and found locally afterwards
   (`ModelUtilities.loadTokenizer` searches local folders first; ArgmaxCore's local
   `AutoTokenizer.from(modelFolder:)` documents the hub API as unused).
9. **Top-half fallback**: if Whisper's translate output still contains Arabic
   letters, Apple Translation (ar to en) is tried when its pack is installed;
   otherwise the cleaned remainder is shown with a note.
10. **Three render paths** in `AppModel` (showTop, showBottom, showStatus), each
    passing through `ScriptGuard.clean` and appending exactly the shown text to the
    day's log in Documents. `UIFileSharingEnabled` makes the log visible in Files.
11. **Hallucination filter**: drop results whose segments all have
    noSpeechProb > 0.6, and a short list of subtitle-credit phrases.

## Flags (ledger or brief vs raw)

- Brief: "First-build model variant: the large-v3 turbo variant (assumed name
  openai_whisper-large-v3-v20240930_turbo)". Raw: OpenAI README "the `turbo` model
  is not trained for translation tasks"; Argmax README "large-v3-v20240930_turbo |
  Recommended on macOS"; config.json does not list it for iPhone18.
- Ledger/brief: "WhisperKit reports one detected language per transcription window."
  Raw agrees, and adds: `detectLangauge` returns `langProbs` with only the winning
  language's log-prob, so no confidence comparison between en and ar is available.
- Ledger F1 (macos-26 image, Xcode 26.6 default at /Applications/Xcode_26.6.app,
  image 20261026.0455.2) re-read raw: matches.
- Ledger F8 (MrKai77 archive command and Payload rename) re-read raw: matches.

## Build risks, most likely first

1. Unsafe-flags refusal of the package (mitigated by the revision pin).
2. A Swift 6.2 compiler diagnostic that is an error even in Swift 5 mode, most
   likely around isolation in `AppModel.swift` or `ContentView.swift`.
3. A mistyped label in a WhisperKit or Translation call (list in FIRST_RUN.md 2.3).
4. Runtime, not compile: first Core ML specialization of large-v3 on the phone may
   take many minutes; foreground memory with large-v3 plus tomorrow's 4B model (R10).
5. Runtime: Whisper large-v3 translate quality on Egyptian dialect is unmeasured (R2).

## What was run here

- actionlint 1.7.12 (Windows binary from its GitHub release, shellcheck disabled
  because it is not installed): clean on `ios-build.yml`.
- PyYAML parse of `project.yml` and the workflow: both parse to the intended structure.
- A bracket-balance script over every Swift file: balanced; an ASCII scan: no
  non-ASCII characters in Swift sources.
- Every WhisperKit call checked against a shallow clone of tag v1.1.1; every
  Translation call against developer.apple.com documentation JSON.
- Nothing was compiled. Nothing ran on a phone.
