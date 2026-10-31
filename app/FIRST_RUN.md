# Egypt Talk: first cloud build and first install

Nothing in `app/` has ever been compiled. This PC cannot compile Swift. The first
real check is the GitHub Actions run. This file says what that run must show,
where it will most likely break, and how the finished `.ipa` gets onto the
iPhone through AltStore.

## 0. Before the first run

- The repository is https://github.com/ScizoMonke/Arabic-translation-app-for-iPhone (public). Builds appear at https://github.com/ScizoMonke/Arabic-translation-app-for-iPhone/actions.
- The workflow is `.github/workflows/ios-build.yml`. It starts on any push that
  touches `app/` or the workflow file, or by hand: GitHub > repo > Actions >
  ios-build > Run workflow.
- Cost: on a private repo, macOS minutes come out of the free $12/month at
  $0.062/min (ledger F1), so about 190 macOS minutes a month. Public repos are
  free. A run should take roughly 10 to 25 minutes (estimate, not measured).

## 1. What the first run must show, step by step

Open the run in the Actions tab. Each step, and the line that proves it worked:

| Step | Must show |
|---|---|
| Select Xcode 26.6 | `Xcode 26.6` and an iphoneos SDK version starting `26.` |
| Install XcodeGen | `Version: 2.4x.x` |
| Generate Xcode project | `Created project at .../app/EgyptTalk.xcodeproj` |
| Resolve Swift packages | `argmax-oss-swift` at revision `1bbc57cb...` and `swift-argument-parser` in the resolved list, `LlamaBinary` (local), then `resolved source packages`; after it, a path ending in `llama.xcframework` and no `WARNING: llama.xcframework ... not found` line |
| Archive | `** ARCHIVE SUCCEEDED **` at the end |
| Package .ipa | a size line for `EgyptTalk.ipa` (now a few tens of MB: llama.framework is about 12 MB; neither model is inside, both download on the phone), then `CFBundleIdentifier => "com.a2e.egypttalk"`, `CFBundleDisplayName => "Egypt Talk"`, `MinimumOSVersion => "26.0"`, the microphone sentence, `llama.framework` listed under Frameworks, and either `phrasebook.json bundled (N bytes)` or `phrasebook.json not bundled` |
| Upload .ipa | the run page lists an artifact named `EgyptTalk-ipa` |

`build-logs` is uploaded even when the run fails; `archive.log` in it is the
full compiler output. Search it for `error:`.

## 2. Most likely first-compile failures, most likely first

0. **llama.cpp (wave app-2), in this order of likelihood.** llama.cpp ships no
   Package.swift any more; `app/LlamaBinary/Package.swift` is a local package
   whose only target is upstream's prebuilt `llama-b12020-xcframework.zip`
   (binaryTarget, sha256 `78fdf6ec...1ae5`).
   - `llama.framework is not embedded in EgyptTalk.app/Frameworks` in the
     Package step: Xcode linked the dynamic framework but did not copy it. The
     app would die at launch. Fix: in `project.yml`, under the target's
     `dependencies`, give the LlamaBinary entry `embed: true`; if that is not
     enough, replace the package with a `framework:` dependency on the unzipped
     `llama.xcframework` downloaded by a workflow step (same URL, same checksum).
   - Resolve fails with `checksum ... does not match` or `does not contain a
     binary artifact`: the release asset changed or the zip layout did. Re-read
     the asset digest on the GitHub release page and the zip's top folder
     (`build-apple/llama.xcframework`; SwiftPM 6.2 strips one folder level).
   - Swift errors in `LlamaEngine.swift`: a C import shape. Every symbol was
     checked against `include/llama.h` at b12020; the usual suspects are
     `LLAMA_LOAD_MODE_MMAP` (C enum constant), `llama_model_get_vocab` returning
     `OpaquePointer`, and `llama_batch_get_one` taking a mutable pointer.
   - Swift errors in `SessionLog.swift` (`MemoryProbe`): `task_vm_info_data_t`,
     `TASK_VM_INFO`, `os_proc_available_memory()`. If one name refuses, delete
     that field from the line rather than the whole probe.
   - `ModelDownloader.swift`: CryptoKit `SHA256`, `FileHandle.read(upToCount:)`.
1. **Package refused for unsafe flags.** Symptom in `archive.log` or the
   resolve step: `The package product 'WhisperKit' cannot be used as a dependency
   of this target because it uses unsafe build flags.` Cause: WhisperKit v1.x's
   `Package@swift-6.2.swift` puts `-enable-library-evolution` in `unsafeFlags`.
   Already mitigated: `app/project.yml` pins the package by **revision**, which
   SwiftPM allows to vend unsafe flags (version pins are not). If it still
   fails: change the pin in `project.yml` to `branch: main` and retry; last
   resort is `exactVersion: 0.15.0` (no unsafe flags, but pre-1.0 API, so
   `Transcriber.swift` calls must be re-checked against that tag).
2. **Swift concurrency diagnostics turned into errors.** The app target is in
   Swift 5 language mode (`SWIFT_VERSION: "5.0"` in `project.yml`) so that
   non-Sendable WhisperKit and TranslationSession crossings are warnings. Places
   that would break if they ever become errors: `AppModel.swift` (the
   `romanizer.render` call, the `transcriber.download` progress closure),
   `AppleTranslator.swift` (`session.translate`), `MicCapture.swift` (the tap
   closure and the notification observers). Lots of yellow warnings are
   expected and fine.
3. **An API name or label typed wrong.** Every one was read from the v1.1.1
   source or Apple's documentation JSON, but none has met a compiler:
   - `Transcriber.swift`: `pipe.detectLangauge(audioArray:)` (the misspelling is
     WhisperKit's own), `WhisperKit.download(variant:downloadBase:from:progressCallback:)`,
     `WhisperKitConfig(downloadBase:modelFolder:tokenizerFolder:verbose:logLevel:prewarm:load:download:)`
     (labels must stay in that order), `DecodingOptions(task:language:temperatureFallbackCount:usePrefillPrompt:detectLanguage:skipSpecialTokens:withoutTimestamps:)`.
   - `MicCapture.swift`: `AudioProcessor.resampleBuffer(_:with:)`,
     `AudioProcessor.convertBufferToArray(buffer:)`, `WhisperKit.sampleRate`.
   - `AppleTranslator.swift`: `TranslationSession(installedSource:target:)` (iOS 26),
     `LanguageAvailability().status(from:to:)`.
   - `ContentView.swift`: `TranslationSession.Configuration(source:target:)`,
     `.invalidate()`, `.translationTask(_:action:)`, and the
     `switch model.translationStatus` with `@unknown default`.
   - `AppModel.swift`: `AVAudioApplication.requestRecordPermission()` (async form,
     the same call WhisperKit itself makes).
4. **XcodeGen spec detail.** If `xcodegen generate` complains, the culprit is
   `app/project.yml`; the package key `argmax-oss-swift` must match the
   `package:` name under the target's dependencies.
5. **Xcode 26.6 missing on the image.** The select step falls back to the
   image default and prints what exists; any Xcode 26.x is fine.

## 3. Getting the .ipa onto the iPhone (no Xcode, no Mac)

AltStore installs the app signed with your own Apple ID. A free Apple ID's
signature lasts 7 days; after that the app will not open until it is refreshed
from this PC (same Wi-Fi as the phone, AltServer running). Plan the refresh
before the trip and know when it expires (D8, R9).

One-time setup on the Windows PC:
1. Install iTunes and iCloud **from apple.com**, not from the Microsoft Store
   (AltStore's FAQ says the Store versions do not work; uninstall them first if
   present).
2. Install AltServer for Windows from altstore.io and run it; it lives in the
   system tray. Allow it through the Windows firewall when asked.
3. Plug the iPhone in with a cable. Unlock it and tap **Trust** on the phone.
4. In iTunes, select the phone and tick "Sync with this iPhone over Wi-Fi"
   (lets AltServer refresh later without the cable).
5. Click the AltServer tray icon > Install AltStore > pick the iPhone. Sign in
   with your Apple ID when asked.
6. On the iPhone: Settings > Privacy & Security > Developer Mode > On, restart,
   confirm. Then Settings > General > VPN & Device Management > your Apple ID >
   Trust.
7. AltStore now appears on the home screen.

Each new build:
1. On GitHub: Actions > the green ios-build run > Artifacts > download
   `EgyptTalk-ipa`. It is a .zip; unzip it to get `EgyptTalk.ipa`.
2. Put `EgyptTalk.ipa` on the phone: copy it into the iCloud Drive folder on the
   PC (installed in step 1), wait for it to sync, then on the phone open
   AltStore > My Apps > **+** (top left) > pick `EgyptTalk.ipa` in Files.
   Alternative, unverified from memory: Shift-click the AltServer tray icon >
   "Sideload .ipa" > pick the file, with the phone on the cable.
3. AltStore signs and installs it. "Egypt Talk" appears on the home screen.
   Installing a newer build over it keeps the downloaded model.

Free Apple ID limits (Apple, ledger F3): 3 sideloaded apps per device including
AltStore itself, 10 App IDs per 7 days.

## 4. First launch on the phone (at home, on Wi-Fi)

1. Open Egypt Talk. Tap **Download the two models**. Two downloads run one
   after the other: "Speech model (1 of 2, about 950 MB)", then "Egyptian
   model (2 of 2, about 2.5 GB)". Keep the app open and the screen on; on home
   Wi-Fi expect several minutes to half an hour in total. The Egyptian model
   downloads over Wi-Fi only, never mobile data.
   - If it stops ("download stopped"), tap **Try again**, then the download
     button: it continues from where it stopped (the part already on the
     phone is kept). At the end the app checks the exact size (2,489,894,752
     bytes) and the SHA-256 fingerprint before using the file; a corrupted
     file is deleted and must be downloaded again.
   - Already-installed builds that have the speech model skip straight to
     "2 of 2".
2. "Preparing the speech model for this phone" follows. The first time can take
   several minutes while Core ML compiles the model for the A19 Pro. Then
   "Loading the Egyptian model" (seconds). Do not leave the app.
3. Allow the microphone. The split screen appears with a green dot: listening.
4. **Needed for the meaning check:** tap the gear in the middle bar (or use the
   section at the bottom of the setup screen) > Download Apple Arabic pack.
   Without it, the line under each Egyptian sentence reads "Meaning check
   unavailable".
5. **Offline proof (D9):** turn on Airplane Mode, swipe the app away, open it
   again. It must come back to the split screen with no network. If it shows
   the setup screen or an error instead, the offline promise is broken: report
   the exact message.
6. Do not install iOS updates during the trip: an OS update throws away Core ML's
   compiled copy, and the next launch repeats step 2 (it still works offline,
   it is just slow once).

## 5. The checks from the mission

- Someone speaks Egyptian Arabic: English appears in the top half ("THEY SAID").
- He speaks English: a card appears in the bottom half ("YOU SAY"): what he
  said, the Egyptian to say in plain Latin letters (largest), "Means: ..." (the
  meaning check), and a small tag saying where the Egyptian came from. Section
  6 has the exact checks.
- He never touches the phone: each utterance lands in its half by itself. When
  it lands wrong, the Auto/Them/Me switch in the middle bar forces the side.
- No Arabic letters anywhere.
- The dot: grey = mic off, green = listening, orange = hearing speech; a spinner
  next to it means a sentence is being processed.
- The session log: Files app > On My iPhone > Egypt Talk > `EgyptTalk-YYYY-MM-DD.txt`,
  one line per thing shown.

## 6. The bottom half on the phone (wave app-2)

Do these at home, after section 4, with the Apple Arabic pack installed.
Switch the middle bar to **Me** for these checks so detection cannot send your
English to the top half (R12); then repeat one of them on **Auto**.

1. **Phrasebook hit.** Say "Where is the bathroom?". Expect a card whose tag
   reads `phrasebook` (or `phrasebook, close to "..."` when your wording was
   close to one of its phrasings, shown so you can see what it matched). The
   Latin line and the "Means:" line are the phrasebook's own, vetted. It
   appears almost at once. If the tag says `model` instead, either this build
   carries no phrasebook (the CI Package step said `phrasebook.json not
   bundled`, and the status line at launch said "No phrasebook in this build")
   or that phrase is not in it yet: check the status line at launch for
   "Phrasebook: N phrases".
2. **Model.** Say something nobody would put in a phrasebook, for example "My
   cousin's dog ate my sandwich yesterday." Expect, within a few seconds, a
   spinner next to YOU SAY ("working out the Egyptian"), then a card tagged
   `model` (or `model, second try`). The Latin line is lowercase letters with
   apostrophes where Egyptians stop the breath ("ma' el salama"). Read the
   "Means:" line: it is Apple's translation of the Egyptian back into English,
   made by a different engine. If it does not mean what you said, do not say
   that sentence.
   - Tag `model, ROUGH: letters only, vowels missing`: the model failed twice
     to spell it properly and this is a letter-by-letter fallback. Treat it as a
     hint, not a script; rephrase shorter.
   - `[the model could not answer this one]`: rephrase shorter.
3. **Talking over it.** While a card is still being worked out, have someone
   speak Arabic. Their English must still appear in the top half without
   waiting for your card: the microphone and Whisper never wait for the
   Egyptian model.
4. **Memory line in the log.** Open Files > On My iPhone > Egypt Talk >
   today's `EgyptTalk-YYYY-MM-DD.txt`. After each load and each sentence there
   is a line like
   `MEM footprint 3100 MB, peak 4200 MB, resident ..., peak resident ..., headroom 1900 MB (after my sentence)`.
   Report the largest `peak` and the smallest `headroom` you see after a few
   minutes of both halves working. The phone's ceiling for one app is about
   6 GB (R10). Lines starting `  diag:` under each card give the model timings,
   and for rejected answers the raw model text with Arabic letters written as
   `\u{0627}`-style codes (so no Arabic shows even in the log).
5. **Offline.** Airplane Mode, swipe the app away, reopen: the setup screen must
   not come back, and checks 1 and 2 must still work.

### If the app is killed for memory

Symptom: the app vanishes back to the home screen while loading the Egyptian
model or while working on a sentence, with no message. iOS ends apps that pass
their memory limit without a warning.

1. Reopen it and note where it died: the last `MEM` line in today's log tells
   how high it got and at which moment ("after Whisper load", "after Egyptian
   model load", "after my sentence"; "before Egyptian model load" as the last
   one means it died while loading). If it died while loading the Egyptian
   model, the next launch skips that model once and says so in the status line
   ("Egyptian model skipped this time"), so the top half still works; the
   launch after that tries again.
2. Restart the phone once and try again. The per-app limit itself does not
   change, but a fresh start clears memory other apps were holding, which can
   decide a borderline case.
3. Report the last `MEM` lines. The fixes on our side, in order: a shorter
   context (2048 to 1024 tokens, `LlamaEngine.contextLength`), the smaller
   4-bit file `Nile-Chat-4B.Q4_K_S.gguf` from the same repository, or loading
   the Egyptian model only when you speak English. Each is a new build, not
   something to change on the phone.

## 7. This build (wave app-4): hold to talk

Install it exactly like the last one (section 3). It installs over the old app
and keeps both downloaded models; no setup screen.

**What changed on screen.**
- The Auto/Them/Me switch is gone. Wherever sections 5 and 6 say to use it,
  ignore that: nothing guesses who is speaking any more.
- The top half ("THEY SAID") listens all the time and treats everything it
  hears as Arabic. It shows English or nothing: when Whisper writes Arabic in
  Latin letters instead of translating, the app writes the Arabic down and has
  Apple translate it (that line carries "via Apple Translate"); if that cannot
  work either (Apple Arabic pack missing), the line is dropped and only the log
  keeps it.
- The bottom half ("YOU SAY") is now the talk button. A hint under YOU SAY says
  "Press and hold anywhere here, speak English, let go."
- The middle dot: green "Listening for Arabic", orange "Hearing", blue "Your
  turn: top half paused" while you hold.

**First launch of this build.** iOS asks once for **Speech Recognition**:
allow it. If the hint under YOU SAY turns red, it says what is missing:
- "Speech recognition is off": Settings > Apps > Egypt Talk > Speech Recognition on.
- "English offline recognition is not on this phone yet": at home on Wi-Fi,
  Settings > General > Keyboard > Enable Dictation on, wait a few minutes,
  reopen the app. Your English is recognized on the phone only, never online.

**The hold.** Press anywhere on the bottom half and keep your finger down. The
half turns blue, the top half pauses, and your English appears live under
"Listening to you" as you speak. Lift your finger when done: the card appears.
While you hold, nothing you say can reach the top half, and it starts
listening again half a second after you let go. A tap shorter than a third of
a second with no words is ignored. A hold ends by itself after a minute, and
when you leave the app. The old cards no longer scroll by hand (touching the
half means talking); the newest is always in view and the log has them all.

**Checks for this build.**
1. Someone speaks Arabic, you touch nothing: English in the top half. No line
   of Arabic in Latin letters (like "ana mesh 3aref") may appear there.
2. Hold, say "Where is the bathroom?", let go: a `phrasebook` card. Target:
   under about 2 seconds from letting go.
3. Hold, say a sentence no phrasebook has, let go: a `model` card. Target:
   about 3 seconds.
4. While holding, have someone speak Arabic too: nothing lands in the top half
   until you let go.

**Reading the timing lines in the log** (Files > On My iPhone > Egypt Talk >
today's file). Times are the phone's clock with milliseconds.
- Under each card:
  `TIME me: release 14:02:03.120 | heard-final 14:02:03.540 (+420 ms) | card 14:02:04.900 (+1780 ms after release) [phrasebook]`
  The last number is what you felt as the wait. `heard-final` minus `release`
  is Apple finishing your English; the rest is the phrasebook or the model.
- Under each top line:
  `TIME them: utterance-end 14:02:01.000 | line 14:02:03.200 (+2200 ms) [translate]`
  `utterance-end` is when the app decided they stopped, which is about 0.8 s
  after their last word (the quiet it waits for).
- The tag in brackets on `THEM:` and `TIME them:` lines says which path made
  the line: `translate` (Whisper directly), `fallback-apple` (Whisper wrote
  Arabic, Apple translated it), `dropped` (nothing shown; the `THEM dropped:`
  line above it says why and keeps the raw text, Arabic letters as
  `\u{0627}`-style codes).
- Model cards also have a `diag:` line like
  `model greedy: 290 prompt (262 reused from cache) + 31 new tokens, 1.40 s`:
  the reused number should be most of the prompt on every sentence. At launch
  a `diag:` line says `prefix cached: N tokens`.

**What to report after a session**: the `TIME me` lines (the last number of
each), how many `THEM:` lines were `translate`, `fallback-apple` and `dropped`
(R27), and as before the largest `peak` and smallest `headroom` from the `MEM`
lines.
