# Wave app-4 account (2026-10-31): hold to talk, Apple English, translate fallback, prefix cache

Branch app-4, commits af5d435 (plan) .. 7039e98 (FIRST_RUN) + 9784a83 (PrimeResult). Commits 1-4 do
not compile alone; the branch head is the unit the cloud build checks.

## Decisions taken here

- Recognizer: SFSpeechRecognizer(en-US) + SFSpeechAudioBufferRecognitionRequest, requiresOnDeviceRecognition,
  partials on, addsPunctuation, taskHint .dictation. Not SpeechAnalyzer: it would need an AssetInventory download
  flow, a format converter to its preferred format, and more unverified API surface; SFSpeech takes the tap's
  native buffers and endAudio() maps 1:1 onto release. Doc JSON read for 23 symbols, none deprecated on iOS.
  The result handler's thread is not guaranteed main (doc: `queue` does not apply to it), so only Strings and a
  Bool cross into a Task @MainActor.
- No offline English means no recognition, not network recognition (D9). The state is shown in red under YOU SAY.
- Gesture: transparent overlay on the whole bottom half, DragGesture(minimumDistance: 0) writing a @GestureState.
  GestureState resets on lift and on system cancel, so onChange(of: pressing) always sees the end. Cost: the
  bottom history no longer scrolls by hand (auto-scroll to newest stays). Chosen over a long-press because a
  long-press fires after a delay and its end callback is not a touch-up.
- Every hold pauses the top half, including a hold Apple cannot hear (sink discards). Hold state lives in
  MicCapture under an NSLock and survives engine restarts, so a restart mid-hold cannot route him to Whisper.
  Cutter's utterance in progress discarded at both ends; cutter muted 0.5 s after release. Safety: 60 s cap,
  hold ended on background. Under 300 ms with no partial text: ignored, diag line only.
- Release waits at most 2 s for Apple's final result, then uses the last partial (logged as a recognizer note).
- Top half: translate (prompted) -> NLLanguageRecognizer.dominantLanguage(for:) == .english and no Arabic script
  -> shown [translate]. Else, only if the Apple pack is installed: unprompted transcribe ar -> AppleTranslator ->
  same English check -> shown with "via Apple Translate" [fallback-apple]. Else nothing shown; `THEM dropped:`
  line with reason and both raw outputs escaped [dropped]. Strict on purpose: "undetermined" counts as not
  English, so a lone "OK" may cost the second pass or be dropped without the pack.
- Whisper prompt: " The following is an English translation of Egyptian Arabic speech." encoded with the
  pipeline tokenizer at load, specials filtered, passed as promptTokens (WhisperKit 1bbc57cb TextDecoder lines
  198-206 put it after <|startofprev|>; output text is sliced from SOT, so the prompt never appears). A prompt
  echoed on silence is filtered as a hallucination.
- Prefix cache cut: after the "\n\n" closing the folded system text, before `English: "`. Correctness does not
  depend on the cut: each request tokenizes the full prompt as before, keeps the longest common token prefix with
  `cachedTokens` (exact mirror of KV positions 0..n-1), seq_rm's the rest, checks pos_min == 0 and
  pos_max == keep-1, decodes the remainder. Any failure clears cache and mirror together. The mild retry reuses
  all but the last prompt token. Verified at b12020 source: llama_batch_get_one positions continue at
  seq_pos_max+1 (llama-batch.cpp 1427); swa_full defaults true (llama-context.cpp 4079), so Gemma 3's SWA cache
  keeps every position; iSWA seq_rm forwards to both caches.
- Rendered prompt: identical to the pre-D37 expression (Python emulation of both Swift expressions, 1228 chars,
  prefix 1160); differs from the bench twin only by the D24 Rules block, as recorded.
- Live heard line is a fourth screen path, cleaned by ScriptGuard and transient; it is not logged (the card's
  heard line is). Flagged as a deliberate exception to "log equals screen".
- Timestamps: HH:mm:ss.SSS local (ISO 8601 extended time), plus computed deltas in ms. Top "utterance-end" is the
  cutter's decision time, about 0.8 s after the last word.

## Ran here

- actionlint 1.7.12 (shellcheck off) on ios-build.yml: clean. PyYAML: project.yml and workflow parse; the new
  plist key is present.
- Bracket-balance and ASCII scan over all 15 Swift files: balanced; non-ASCII only in the two Arabic prompt
  examples (pre-existing).
- Prompt identity check (old vs new render expression) and bench diff, as above.
- No Swift compiler, no device. Nothing here proves it compiles or that the hold feels right.

## Build risks, most likely first

1. Concurrency diagnostics in Swift 5 mode around Speech: @Sendable closures capturing the non-Sendable request,
   MainActor state set inside withCheckedContinuation's body. Expected warnings, not errors, in Swift 5 mode.
2. SwiftUI: GestureState + onChange(of:) two-argument form + overlay gesture on a view holding a ScrollViewReader.
3. llama C interop on the new calls: llama_memory_seq_rm / seq_pos_min / seq_pos_max with an OpaquePointer?
   memory handle (same shape llama_memory_clear already compiled with).

## Runtime risks for the phone test

- Apple's recognizer can declare a result final on its own after a long pause while he is still holding; this
  build then ignores the rest of that hold. If he sees his card cut short after pausing mid-sentence, that is it.
- Plugging or unplugging a headset mid-hold changes the input format under a running request (may end it).
- The English prompt's effect on translation quality is unmeasured (R27); the log counts the paths.
- Prefix reuse feeds the model identical tokens, but batch boundaries differ from the uncached run, so float
  rounding can, in rare near-ties, flip one greedy token relative to the old build.

## Outside scope, noticed

- FIRST_RUN sections 5 and 6 still describe the switch and Me mode; section 7 overrides them in one line.
- MicCapture.close() writes lastSpeaking on the main thread while the tap thread also writes it (pre-existing).
- AppleTranslator's header comment still speaks of "tomorrow's Romanizer" (stale, harmless).
- A dropped top line leaves no trace on screen; he cannot tell that something was said and not shown.
