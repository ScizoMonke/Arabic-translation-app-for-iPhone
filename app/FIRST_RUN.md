# Egypt Talk: first cloud build and first install

Nothing in `app/` has ever been compiled. This PC cannot compile Swift. The first
real check is the GitHub Actions run. This file says what that run must show,
where it will most likely break, and how the finished `.ipa` gets onto the
iPhone through AltStore.

## 0. Before the first run

- A GitHub repository holding this repo, with branch `app-1` pushed (register R11).
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
| Resolve Swift packages | `argmax-oss-swift` at revision `1bbc57cb...` and `swift-argument-parser` in the resolved list, then `resolved source packages` |
| Archive | `** ARCHIVE SUCCEEDED **` at the end |
| Package .ipa | a size line for `EgyptTalk.ipa` (a few MB to a few tens of MB; the speech model is NOT inside, it downloads on the phone), then `CFBundleIdentifier => "com.a2e.egypttalk"`, `CFBundleDisplayName => "Egypt Talk"`, `MinimumOSVersion => "26.0"`, and the microphone sentence |
| Upload .ipa | the run page lists an artifact named `EgyptTalk-ipa` |

`build-logs` is uploaded even when the run fails; `archive.log` in it is the
full compiler output. Search it for `error:`.

## 2. Most likely first-compile failures, most likely first

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

1. Open Egypt Talk. Tap **Download speech model** (about 950 MB). Keep the app
   open and the screen on.
2. "Preparing the model for this phone" follows. The first time can take
   several minutes while Core ML compiles the model for the A19 Pro. Do not
   leave the app.
3. Allow the microphone. The split screen appears with a green dot: listening.
4. Optional backup: tap the gear in the middle bar > Download Apple Arabic pack.
5. **Offline proof (D9):** turn on Airplane Mode, swipe the app away, open it
   again. It must come back to the split screen with no network. If it shows
   the setup screen or an error instead, the offline promise is broken: report
   the exact message.
6. Do not install iOS updates during the trip: an OS update throws away Core ML's
   compiled copy, and the next launch repeats step 2 (it still works offline,
   it is just slow once).

## 5. The checks from the mission

- Someone speaks Egyptian Arabic: English appears in the top half ("THEY SAID").
- He speaks English: a card appears in the bottom half ("YOU SAY"). Until the
  bottom-half model lands, its middle and last lines read `[STUB] ...`; the top
  line ("You: ...") must already be what he said.
- He never touches the phone: each utterance lands in its half by itself. When
  it lands wrong, the Auto/Them/Me switch in the middle bar forces the side.
- No Arabic letters anywhere.
- The dot: grey = mic off, green = listening, orange = hearing speech; a spinner
  next to it means a sentence is being processed.
- The session log: Files app > On My iPhone > Egypt Talk > `EgyptTalk-YYYY-MM-DD.txt`,
  one line per thing shown.
