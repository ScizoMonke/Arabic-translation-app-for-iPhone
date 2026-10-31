# account-5: live top half (D43)

Branch app-5, commits 3799a0f (plan) .. this one. No compiler here; nothing below has been built.

## Mechanism (decided by the executor)
- WhisperKit's AudioStreamTranscriber (1bbc57cb, Sources/WhisperKit/Core/Audio/AudioStreamTranscriber.swift) was read and not used: it opens its own microphone via AudioProcessor.startRecordingLive, keeps every sample since start (clipTimestamps skip, never purges), and confirms only when a decode has more than requiredSegmentsForConfirmation (2) segments. It cannot carry the D34 hold seal. The example app's eager mode (WhisperAX ContentView.transcribeEagerMode) is LocalAgreement on word timestamps with prefixTokens; it needs alignment heads (supportsWordTimestamps) and was not adopted.
- Own loop instead. MicCapture's energy gate (Segmenter, unchanged thresholds: 0.3 s pre-roll, 0.8 s hangover, 0.35 s minimum loud) now only gates; audio goes into LiveWindow (lock-guarded, utterance marks, generation counter). AppModel.runLiveTop polls every 100 ms; a decode is due when an utterance closed, or when the open one has >= 0.35 s loud audio, >= 1.2 s in the window, and >= tick (1 s turbo, 2 s large-v3) of new audio since the last decode. One decode at a time; nothing queues.
- Settle rule (AppModel.settleCount): never the last segment; a prefix of the others settles when each is letter-identical to the same position in the previous decode of the same window, or ended >= 4 s before the newest audio, or the window is >= 24 s. A closed utterance (0.8 s quiet) gets a final decode of exactly its audio and settles everything. Cut = max(last settled end, first unsettled start), clamped; a cut of 0 settles nothing. advance(by:generation:) is atomic with the generation check, so a decode from a window a hold emptied settles nothing.
- Settled Arabic -> AppleTranslator -> immutable TopLine (logged with the Arabic escaped). Unsettled Arabic -> AppleTranslator -> liveTail (lighter italic, "..."), shown only if the window generation is unchanged and no hold is active; cleared when settled words would repeat in it.
- Decode options (live): transcribe, ar, timestamps on, temperatureFallbackCount 1, prefill, no language detection. Audio under 1.2 s is zero-padded (WhisperKit's windowClipTime 1.0 s would otherwise decode nothing; Whisper pads to 30 s with zeros anyway).

## PC twin (scratchpad, not in the repo)
stream_twin.py: the same settle/cut rule in Python with faster-whisper large-v3-turbo (ct2, greedy, timestamps, no VAD) on the 30 mgb3 clips, each treated as one unbroken utterance (the hard case: the window must roll, never flush mid-clip). Run twice (cut = next start; cut = max(prev end, next start) as in the Swift):
- boundaries 209 / 206; boundary word repeated 2 / 2
- WER vs reference: streamed 0.399 / 0.399; one offline pass 0.432 / 0.423 (offline varies run to run through temperature fallback)
- words streamed 1,649 vs offline 1,585; settled pieces median 7.5 per ~25 s clip; 747 decodes
Reading: the boundary neither duplicates nor drops systematically. Limits: faster-whisper is not WhisperKit (segmentation and timestamps can differ), and no energy gate or Apple translation was simulated.
Paths: C:\Users\Optimum\AppData\Local\Temp\claude\c--VScode-Arabic-to-English-to-Arabic-IOS\385c204a-aad6-4444-8757-3e99b8d2f69d\scratchpad\twin\ (stream_twin.py, twin_results.jsonl, twin_run.txt, twin_run1.txt). The scratchpad is session-scoped; move to bench/ if it should be kept.

## Models and gate
- Live: openai_whisper-large-v3-v20240930_turbo_632MB (646 MB on HF). Full turbo openai_whisper-large-v3-v20240930_turbo (1,638 MB) is one constant away (Transcriber.liveVariant); not chosen because Argmax's config.json lists only the 632MB build for the iPhone18 identifiers, although the field log (headroom >= 2,774 MB) says memory would allow it.
- Fallback: openai_whisper-large-v3_947MB under the old UserDefaults key, so the copy on his phone is reused. WhisperKit picks the tokenizer from model dimensions (51866 logits, 1280 encoder -> largev3), so turbo and large-v3 share the cached openai/whisper-large-v3 tokenizer: D9 holds even if large-v3 first loads abroad.
- Only one Whisper is loaded. Pack installed -> turbo (live). Turbo throws -> large-v3 live at 2 s (R31). Turbo killed the app during load last time (marker) -> large-v3 live this launch. Pack missing (gate passed before) -> large-v3 translate per utterance with the English prompt + NaturalLanguage check (only place they survive).
- Gate: phase .needsArabicPack after downloads, first setup only (UserDefaults arabicPackGatePassed, set as soon as the pack is seen installed). Passes by itself when refreshTranslationStatus sees .installed (load runs in an unstructured Task so SwiftUI cancelling the setup view's task cannot cut it). "Continue without it" exists only when Apple reports .unsupported.

## Log
- THEM: <english> | ar "<escaped>" [live]  (R30 grading pairs)
- TIME them: speech-start | first-live (+ms) | settle (+ms; ms after its words) [live|untranslated|dropped]
- TIME them on no speech / error / dropped on both paths (R29). speech-start is the utterance's first sample including the 0.3 s pre-roll, so first-live is overstated by up to 0.3 s (conservative).

## Deleted (named in commit messages)
Utterance, MicCapture.utterances, the Segmenter's own buffer and 25 s cut (moved to the per-utterance loop), Transcriber.transcribeArabic, the D36 Apple-recovery branch of handleTheirs, TopLine.note and its view, showTop.

## Commit steps vs brief
Model variants (ae7927b), window (c40f258), translation + live view + pack gate in one commit (7421028: the three are entangled in AppModel), read-back fixes (054f3ec), FIRST_RUN (c15fda6). Intermediate commits do not compile on their own; only the branch head is meant to.
