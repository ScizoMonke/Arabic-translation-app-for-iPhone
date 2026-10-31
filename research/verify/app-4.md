# Verify app-4 (head 306b63f, tree C:\VScode\a2e-wt\app-4\app) - 2026-10-31

Sources fetched: developer.apple.com/tutorials/data/documentation/speech/*.json; argmax-oss-swift @1bbc57cb Sources/WhisperKit/Core/{Configurations,Models,WhisperKit,TextDecoder}.swift; ggml-org/llama.cpp @b12020 include/llama.h.
All paths below are under app\EgyptTalk\ unless stated.

## 1. Audio path during a hold - FINDING (minor, not his voice)

CLAIMED (MicCapture.swift:99-107, AppModel.swift:309-313): while holding, nothing reaches the top half.
MEASURED, the tap path is sealed:
- Tap closure MicCapture.swift:208-221 calls `guard self.routeOutsideCutter(buffer) == false else { return }` BEFORE resample and BEFORE `consume`. Only `consume` (271-280) calls `segmenter.push` and `continuation.yield`. No other caller of either.
- routeOutsideCutter 250-267 under `holdLock` (118): `let sink = holdSink; let discard = discardPending; ...; let muted = mutedUntil.map { Date() < $0 } ?? false`. `if let sink { sink(buffer); return true }`; `return muted`.
- Press (beginHold 166-173): `holdSink = sink; discardPending = true; mutedUntil = nil` under lock. First tap buffer afterwards runs `segmenter.discardUtterance()` (40-46: clears current, preRoll, inSpeech, quietRun, speechRun) so a half-built utterance (cutter state) is dropped. Window: the one buffer already inside the tap callback at the instant of press (about 85-93 ms) still goes to the cutter; it is pre-press audio.
- Release (endHold 177-184): `holdSink = nil; discardPending = true; mutedUntil = now + releaseMute (0.5, line 117)`. For 0.5 s routeOutsideCutter returns `muted == true`, buffers dropped before the cutter. The cutter is also discarded again on first post-release buffer.
- Engine restart mid-hold: open() 186-235 resets `segmenter` but not `holdSink`/`mutedUntil`; hold state survives (comment 105-107 true).
- Caller side: AppModel.beginHold 314-342 sets the sink in all branches (capture nil gets `{ _ in }`, 327), so audio is discarded, never routed to the cutter.

MISMATCH: utterances that the cutter already yielded BEFORE the press sit in the unbounded `utterances` stream (MicCapture.swift:138) and are consumed by `for await utterance in mic.utterances { await handleTheirs(utterance) }` (AppModel.swift:294-296). handleTheirs (390) has no `isHolding` check, so a queued or in-flight Whisper pass can add a top-half line while the hold is active. Content is pre-press audio (the people around him), not his voice. Matters only if "top half silent during hold" is read as "no top lines appear".
Minor, unclaimed: a tap callback that fetched `sink` just before release can call `request.append` after `endAudio()` (finish() 453 runs in a Task after endHold). Window is microseconds; Apple docs do not say what append-after-endAudio does. Not verified.

## 2. Resume after release - CLEAN
- No engine restart: `running` stays true (129), tap stays installed. endHold reports `.listening` (183).
- After `mutedUntil` passes, `muted` is false (255), `routeOutsideCutter` returns false, tap proceeds to resample (215) and `consume` (220, 271-280): `segmenter.push` -> `continuation.yield(Utterance(...))` (274). Segmenter was cleared (discardUtterance) so a fresh utterance can form; noise floor kept (38-39). `lastSpeaking` reset (260) so `.hearing` is reported again (276-278). beginHold again resets mutedUntil (170).

## 3. Top-half output rule - CLEAN
- Only one write: AppModel.swift:495 `topLines.append(TopLine(english: text, note: cleanNote))` (497 removeFirst only trims). `TopLine(` constructed only at 495 (grep). ContentView.swift:26 reads `model.topLines` only.
- (a) showTop 487-503: `let text = ScriptGuard.clean(english)` (488), note cleaned (489), empty after clean -> logDroppedTop and return (490-494).
- (b) showTop has two callers, both after englishCheck: 405 (`first.isEnglish`, from 403) with Whisper translate text; 424 (`second.isEnglish`, from 421) with `translator.toEnglish(arabic)` = AppleTranslator (AppleTranslator.swift:382-396) output. Everything else goes to logDroppedTop (437), which shows nothing.
- englishCheck AppModel.swift:442-450:
  `if ScriptGuard.containsArabic(text) { return (false, "Arabic script") }`
  `guard let language = NLLanguageRecognizer.dominantLanguage(for: text) else { return (false, "undetermined") }`
  `return (language == .english, "language \(language.rawValue)")`
  nil ("undetermined") -> isEnglish false -> fallback path / dropped, matching D40 (decisions.md:49).
- Note: the check runs on the raw string, clean runs after; since containsArabic already rejects Arabic script, clean there only strips bidi controls and collapses whitespace.

## 4. EnglishListener.swift vs Apple docs JSON - CLEAN
All exist, none has deprecatedAt or unavailable on iOS (metadata.platforms iOS entry), none marked deprecated:
- SFSpeechRecognizer init?(locale:) iOS 10 (EnglishListener:345); isAvailable 10 (385); supportsOnDeviceRecognition 13 (358); class func requestAuthorization(_:) unlabeled closure, 10 (351); SFSpeechRecognizerAuthorizationStatus.authorized (355).
- recognitionTask(with:resultHandler:) iOS 10 (395); SFSpeechRecognitionResult.bestTranscription, .isFinal; SFTranscription.formattedString (396-397).
- SFSpeechAudioBufferRecognitionRequest: init(), append(_:) 10, endAudio() 10 (453, 472).
- Request properties: requiresOnDeviceRecognition 13 (387), shouldReportPartialResults 10 (388), addsPunctuation 16 (389), taskHint 10 (390) with SFSpeechRecognitionTaskHint.dictation; SFSpeechRecognitionTask.cancel() (463, 473).
- NSSpeechRecognitionUsageDescription present: project.yml:57 (under info.properties; NSMicrophoneUsageDescription at 54).

## 5. Transcriber.swift vs WhisperKit @1bbc57cb - CLEAN
- Configurations.swift:162 `public struct DecodingOptions`; `public var promptTokens: [Int]?` (180); `public var usePrefillPrompt: Bool` (171); `detectLanguage: Bool? = nil` in init. App call Transcriber.swift:135-144 labels task, language, temperatureFallbackCount, usePrefillPrompt, detectLanguage, skipSpecialTokens, withoutTimestamps, promptTokens: all exist and are in declaration order of the init (186-216).
- TextDecoder.swift:198-205 uses options.promptTokens (prepends `startOfPreviousToken` + trimmed tokens, filters `< specialTokenBegin`), independent of detectLanguage.
- Tokenizer: WhisperKit.swift:28 `public var tokenizer: WhisperTokenizer? { didSet ... }`; Models.swift:1151 `public protocol WhisperTokenizer { func encode(text: String) -> [Int] ... var specialTokens: SpecialTokens { get } }`; Models.swift:1116 `public let specialTokenBegin: Int`. App uses `loaded.tokenizer`, `.encode(text:)`, `.specialTokens.specialTokenBegin` (Transcriber:106-114): matches.

## 6. LlamaEngine prefix cache vs llama.h b12020 - CLEAN
Newly used symbols, all present, none DEPRECATED:
- `llama_memory_t llama_get_memory(const struct llama_context*)` (h:594); `void llama_memory_clear(llama_memory_t mem, bool data)` (h:756); `bool llama_memory_seq_rm(mem, llama_seq_id, llama_pos p0, llama_pos p1)` (h:765; p1<0 = to infinity); `llama_pos llama_memory_seq_pos_min(mem, seq_id)` (h:810), `..._pos_max` (h:817), both -1 when empty; `llama_batch_get_one(llama_token*, int32_t)` (h:966, header says "avoid using it", not DEPRECATED); `llama_decode`, `llama_n_ctx` (h:579) non-deprecated. The deprecated llama_get_state_size / copy_state_data / kv_self_* family is not used.
- Trace (LlamaEngine.swift:210-258): tokens = tokenizePrompt (BOS prepended, 216). `limit = min(cachedTokens.count, tokens.count - 1)` (229); keep = longest common prefix, capped so >= 1 token is decoded. `llama_memory_seq_rm(memory, 0, keep, -1)` (234) drops positions >= keep; consistency check pos_min == 0 and pos_max == keep-1 (238-240), else keep = 0 and `forgetCache` (247-249). `decodeTokens(Array(tokens[keep...]))` (253) decodes exactly tokens.count - keep tokens; llama_batch_get_one continues at pos_max+1 = keep, so the last position is tokens.count - 1 (n_past = tokens.count) and logits are those of the last prompt token for `llama_sampler_sample(..., -1)` (279). `cachedTokens = tokens` (258); each generated token is decoded then appended (295-300); the stopping token is never decoded nor appended, so record and cache agree. Retry (mild) reuses tokens.count-1 and re-decodes the last prompt token. Failure paths forget both cache and record.
- Not verifiable here: whether Gemma 3's iSWA cache at b12020 accepts a partial seq_rm (code falls back to full re-decode if it returns false or positions look off, so worst case is slower, not wrong).

## 7. Deletions - CLEAN
grep -rnE "Routing|Speaker|\bHeard\b|process\(|forced|detectLanguage\(|detectLang|Picker|\.them|\.me|\.auto|isTheirs|isMine" over app\ (swift, yml, plist): hits only Transcriber.swift:131 (comment, word "forced"), Transcriber.swift:140 (`detectLanguage: false`, a DecodingOptions label, not the removed call), MicCapture.swift:189 (`mode: .default`), LlamaEngine.swift:127 (comment "AUTO"), project.yml comments. No Auto/Them/Me, Routing, Speaker, Heard type, process(_:forced:) survivors. `liveHeard` is a live property, unrelated.

## 8. Swift hard errors - CLEAN (read all changed files)
Checked: labels against declarations I can see (Rendering memberwise init AppModel:459 vs Romanizer.swift:5-17; engine.prime/PrimeResult; DecodingOptions init order; llama symbols; Speech symbols); awaits/trys (AppModel 176, 206, 396, 412, 414, 420, 457; Transcriber 145); imports (AppModel: NaturalLanguage, Translation, AVFoundation, UIKit; EnglishListener: Speech, AVFoundation; MicCapture: WhisperKit for AudioProcessor/WhisperKit.sampleRate; Swift 5 mode); @MainActor: EnglishListener and EnglishCapture are @MainActor and only touched from AppModel (MainActor) or `Task { @MainActor in }`; the tap thread touches only `request` (non-isolated class) and `holdLock` state; `fileprivate` members used within the same file; implicit self in `Task {}` is allowed (Task.init is @_implicitSelfCapture); `withCheckedContinuation` body inherits MainActor in finish(). @GestureState `pressing` (ContentView:104) is written only via `.updating($pressing)` (176) and read in `.onChange(of: pressing)` (181): allowed use. No hard error found. (No Swift toolchain here; this is a read, not a compile.)

## 9. TIME lines - FINDING (coverage)
Timestamp format: SessionLog.swift:288-293 `dateFormat = "HH:mm:ss.SSS"` (en_US_POSIX, local time), `clock(_:)` at 295. Every log line is also prefixed `[HH:mm:ss] ` (308), so a TIME line looks like `[14:02:04] TIME me: ...`.
- Bottom, written at AppModel.swift:470-472 (deliverMine): `TIME me: release HH:mm:ss.SSS | heard-final HH:mm:ss.SSS (+N ms) | card HH:mm:ss.SSS (+M ms after release) [source]`. release = Date() at AppModel:348 (start of endHold), heard-final = Date() at 369 (after `finish`), card = Date() at 468 (after showBottom). Both +N and +M are integer ms rounded (476-478). Source is ScriptGuard-cleaned rendering.source (e.g. phrasebook, model).
- Bottom, no speech heard, AppModel:376-377: `TIME me: release T | heard-final T (+N ms) | no card, nothing heard` (two timestamps).
- Top, shown, AppModel:501-502: `TIME them: utterance-end T | line T (+N ms) [path]` where path is `translate` or `fallback-apple`; utterance-end is `Utterance.endedAt` = Date() when the cutter yields (MicCapture:274), which is about 0.8 s after speech stopped (hangover, MicCapture:26); line = Date() after topLines.append (499).
- Top, dropped, AppModel:541-542: `TIME them: utterance-end T | dropped T (+N ms) [dropped]`.
- Examples match FIRST_RUN.md:292,296.
MISMATCH against "two per top utterance": top utterances for which Whisper translate returns nil (non-speech, handleTheirs:401 `guard let translated else { return }`) or throws (397-399) write NO TIME line. Also a hold shorter than 0.3 s with no speech writes only a `diag:` line (362), no TIME me. Parser should treat missing TIME lines as expected for those cases.

## Housekeeping
Early in the run a malformed shell command wrote scratch downloads into the repo root of "Arabic to English to Arabic IOS" (Models.swift, WhisperKit.swift, TokenizerUtils.swift, sf*.json); all were moved/removed within the run; `git status --short` was clean afterwards. Nothing else was touched; the only file kept is this one.
