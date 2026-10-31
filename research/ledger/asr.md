# ASR ledger (Egyptian Arabic on iPhone). Read date for all entries: 2026-10-31.
Note: WebFetch returns small-model summaries of pages; quotes below are as returned by the fetch tool, not re-verified against raw HTML.

## Fact 1 - WhisperKit
- Source: argmaxinc/WhisperKit README (Argmax). Evidence: repo-readme. URL: https://github.com/argmaxinc/WhisperKit. Reached: direct fetch.
  - "Argmax recommends `large-v3-v20240930_626MB` for maximum multilingual accuracy and `tiny` for the fastest debugging workflow."
  - Translate (local server): "POST `/v1/audio/translations` - Translate audio to English"
  - Streaming: "Streaming responses: Server-Sent Events (SSE) for real-time transcription"; CLI mic streaming via `--stream`; "Real-time transcription with speakers" is listed as Pro SDK only.
  - License: "Argmax OSS is released under the MIT License."
  - Min iOS: README prerequisites list only "macOS 14.0 or later" for WhisperKit; no iOS minimum stated for WhisperKit (TTSKit "iOS 18.0 or later", SpeakerKit "iOS 16.0 or later").
  - Full variant list (turbo, distil) NOT shown on README fetch. See NOT FOUND below.
- Source: GitHub release page, Argmax. Evidence: release-note. URL: https://github.com/argmaxinc/WhisperKit/releases/latest. Reached: direct fetch.
  - Tag v1.1.1 marked "Latest", "08 Oct" (year not shown on page), commit 1bbc57c. Notes: "a patch release fixing some crashes identified by the community". Repo appears moved/renamed: full notes at https://github.com/argmaxinc/argmax-oss-swift/releases/tag/v1.1.1. Notes mention "drops macOS 14 support" (summary wording).
- NOT FOUND (not yet): list of exact model variants incl. large-v3-turbo and distil in WhisperKit; explicit translate task support in the on-device Swift API (only server endpoint seen); iOS minimum for WhisperKit.

## Fact 3 - whisperkittools
- Source: argmaxinc/whisperkittools README. Evidence: repo-readme. URL: https://github.com/argmaxinc/whisperkittools. Reached: direct fetch.
  - "Convert Hugging Face Whisper Models (PyTorch) to WhisperKit (Core ML) format." Command: `whisperkit-generate-model --model-version <model-version> --output-dir <output-dir>`
  - "lets you create and deploy your own fine tuned versions of Whisper in CoreML format to HuggingFace"; "Once generated, they can be loaded by simply changing the repo name to the one used to upload the model"
  - Setup: Python 3.11 env, `pip install -e .`. Set `MODEL_REPO_ID` to a writable Hub repo to publish. FAQ: coremlcompiler error needs Xcode + xcode-select (i.e. conversion needs macOS/Xcode). Optimization options: "see the help menu with `-h`". License: MIT.
  - Fetch summary says README does not state whether fine-tuned checkpoints are handled differently.

## Fact 4 - Egyptian / dialectal Arabic Whisper models on HF
Search: "whisper egyptian arabic fine-tuned huggingface" (WebSearch). Evidence class for all: model-card.
1. MAdel121/whisper-medium-egy - https://huggingface.co/MAdel121/whisper-medium-egy
   - "This model is a fine-tuned version of openai/whisper-medium on a custom dataset of 72 hours of Egyptian Arabic speech." Data: MAdel121/arabic-egy-cleaned.
   - "Word Error Rate (WER): 18.03%"; "Character Error Rate (CER): 13.38%" on the validation split of MAdel121/arabic-egy-cleaned (no separate test split). License: apache-2.0. Last update: not shown (dataset May 4, 2025; collection May 20, 2025).
2. AbdelrahmanHassan/whisper-large-v3-egyptian-arabic - https://huggingface.co/AbdelrahmanHassan/whisper-large-v3-egyptian-arabic
   - "This model is a fine-tuned version of openai/whisper-large-v3 on the Egyptian-ASR-MGB-3 dataset." (search snippet says LoRA adapter)
   - "Word Error Rate (WER): 0.4739"; eval result "Word Error Rate on Egyptian-ASR-MGB-3" 0.474 "self-reported". No CER, no separate test split named. License apache-2.0. Last update: not shown (dataset "Updated Sep 3, 2024").
3. tawreck-hasaballah/whisper-small-eg - https://huggingface.co/tawreck-hasaballah/whisper-small-eg
   - Fine-tune of openai/whisper-small on "ASR-EGARBCSC: AN EGYPTIAN ARABIC CONVERSATIONAL SPEECH CORPUS". Final eval: Loss 0.5626, WER 47.4960 (steps 125/250/375/500: 52.4512/48.6031/46.5999/47.4960). "the evaluation set" unspecified. Apache-2.0. Last update not shown. Card "More information needed".
4. MightyStudent/whisper-large-v3-arabic - https://huggingface.co/MightyStudent/whisper-large-v3-arabic
   - Base model not stated on card (name implies large-v3; search snippet says large-v3 with PEFT). "Unfortunately, we can't provide the data used in our training." Sources: public online data, web-scraping, YouTube, own recordings.
   - "WER to 30%" and "Character Error Rate (CER) to a whopping 17%" on "the test subset of the Egyptian Arabic dataset" (unnamed). License: mit. Last update not shown.
5. oddadmix/whisper-large-v3-arabic-dialectal-v2 (multi-dialect, not Egyptian only) - https://huggingface.co/oddadmix/whisper-large-v3-arabic-dialectal-v2
   - "`openai/whisper-large-v3` (1.54B) fine-tuned for multi-dialect Arabic on the **dialect-balanced** dataset." Data: oddadmix/lahgtna-v3-small, "52k train / 2.6k test, seed 42, undiacritized output."
   - Overall clean_text WER 0.3199, CER 0.1203. Egyptian (eg), 200 clips: WER 0.271, CER 0.134 (others: sa 0.169, iq 0.254, sy 0.272, ps 0.301, ye 0.304, lb 0.317, ma 0.340, ly 0.343, bh 0.348, dz 0.386, sd 0.399, tn 0.478).
   - Same-card comparison (overall WER/CER): large-v3-v2 0.320/0.120; large-v3-turbo-v2 (809M) 0.332/0.125; medium-v2 (769M) 0.342/0.128; small-v2 (244M) 0.403/0.153; nemotron-3.5-asr-v2 (streaming, 638M) 0.423/0.148; qwen3-asr-1.7b-v2 0.478/0.182; qwen3-asr-0.6b-v2 0.551/0.215; cohere-transcribe-arabic-07-2026-dialectal-v2 0.514/0.294. License apache-2.0. Last update not shown (collection "Updated Jul 29", dataset "Updated Jul 17").
6. Dr-AliGomaa/whisper-large-v3-ar-eg - https://friendli.ai/models/Dr-AliGomaa/whisper-large-v3-ar-eg (Friendli mirror of HF card; reached via search "whisper ArzEn-ST OR MGB-3 OR CALLHOME Egyptian Whisper large-v3 WER evaluation"). model-card.
   - Base "openai/whisper-large-v3". Data: "the MSA mix + 40 h Egyptian (Prof. Ali Gomaa) + MGB-2 folded in for scale + timestamped data".
   - WER/CER (normalized %): Quran 0.50/0.14; Hadith 3.71/1.08; "Egyptian, ar-eg-dataset validation (same speaker/register)" 5.41/1.76; "Egyptian, lahgtna-v3 (zero-shot, unseen speakers, spontaneous)" 17.20/6.32; MGB-2 "in this model's training set; not evaluated." License apache-2.0. Update date not shown. HF page itself not fetched.
7. Other candidates seen in search results only, NOT opened: dev-ahmedhany/whisper-large-v3-turbo-arabic-ft-lora (https://huggingface.co/dev-ahmedhany/whisper-large-v3-turbo-arabic-ft-lora); MightyStudent card also in search.

## Fact 1 addenda (WhisperKit variants / iOS)
- Source: argmax-oss-swift README (successor repo). repo-readme. URL: https://github.com/argmaxinc/argmax-oss-swift. Reached: fetch.
  - Fetch summary: lists two Large v3 Turbo builds `large-v3-v20240930_626MB` and `large-v3-v20240930_turbo`; turbo build "Recommended on macOS for maximum speed and accuracy"; base/small/tiny multilingual and English-only; no distil variants listed. Prereqs "macOS 14.0 or later and Xcode 16.0 or later"; no iOS min for WhisperKit. Translate: only server endpoint "Translate audio to English"; no DecodingOptions translate documented on README. Language detection: server "Automatic language detection or manual specification"; no per-window/per-segment API described. "Real-time WebSocket streaming is offered only in the Argmax Pro Local Server" (summary wording).
- Source: Package.swift in argmaxinc/WhisperKit main. repo (code). URL: https://github.com/argmaxinc/WhisperKit/blob/main/Package.swift. Reached: fetch. "declared as `.iOS(.v16),`" in platforms.
- Source: HF argmaxinc/whisperkit-coreml. model-card. URL https://huggingface.co/argmaxinc/whisperkit-coreml. Fetch returned only a README-like page naming base and "--model "large-v3" --model-prefix "distil"" CLI example; no variant list.
- Source: HF README revision via search result (not opened): https://huggingface.co/argmaxinc/whisperkit-coreml/blob/20f51f218879660aa966596dfe336a762249abe8/README.md. Search-tool summary only: "WER of 2.03 and a file size of 3100 MB for the large-v3_turbo model, and a quantized 954 MB variant with a WER of 2.47" (English LibriSpeech-style; summary, unverified).

## Fact 2 - Argmax performance numbers on iPhones
- Source: Argmax blog "iphone 17 on device inference benchmarks", Argmax, "September 21, 2025". vendor-doc. URL: https://www.argmaxinc.com/blog/iphone-17-on-device-inference-benchmarks. Reached: search "Argmax Whisper iPhone 17 Pro benchmark speed factor large-v3-turbo Neural Engine".
  - "Whisper Large v3 Turbo, uncompressed, iPhone 17 Air: runs at a Speed Factor of 10 (not plotted), up from 4"
  - "This is at the cost of 4x higher memory consumption." (Whisper Large v3 Turbo, uncompressed)
  - "the Neural Engine is 4.3x faster than the GPU for Nvidia Parakeet v3" (iPhone 16 Pro); iPhone 17 lineup GPU gain over iPhone 16 Pro GPU "2.5-3.1x", Neural Engine "1-1.15x"; "iPhone 17 Pro is already up to 3.1x faster than iPhone 16 Pro on iOS 26".
  - Not on page: tokens/s, iPhone 15 Pro, absolute memory in MB. Whisper Large v3 Turbo listed as "1 billion parameters".
  - Search-tool summary (not page-verified): Argmax says its Turbo build uses a weight-compressed format natively accelerated only by the Neural Engine.
- Source: Argmax Parakeet post (search summary only, not opened): https://www.argmaxinc.com/blog/nvidia-frontier-speech-models-on-argmax-sdk - "iPhone speed factor of 180+ for Parakeet v2"; "more than an order of magnitude faster than Whisper Large V3 (and its Turbo variant)" (summary wording).
- Source: Whisper Notes (third party, search summary only): "Turbo on an iPhone 15 Pro at 82 s versus 425 s for large-v3 on 10 minutes of audio". third-party-measurement. Not opened; URL family https://whispernotes.app/blog/introducing-whisper-large-v3-turbo.
- Source: WhisperKit paper arXiv 2507.10860 (Argmax, 14 Jul 2025, ICML 2025 workshop). paper. URL https://arxiv.org/html/2507.10860v1. Fetch summary: "The paper gives no iPhone-specific latency, RTF, or memory figures"; benchmarks on MacBook Pro M3 Max; abstract (search summary): "0.46s" latency and "2.2% WER". Streaming: "applied the LocalAgreement policy to Whisper, leading to dual output text streams"; "Block-diagonal masking enables silence caching". Language detection and translate: not covered.
- Source: argmaxinc/whisperkit-benchmarks Space (https://huggingface.co/spaces/argmaxinc/whisperkit-benchmarks) fetched: no numbers rendered (JS app). dashboard_data/performance_data.json: "File too large to display" (675 kB), not read. BENCHMARKS.md in WhisperKit repo: no results, only instructions; "iPhone 15 Pro Max" appears only in a sample command.
- Argmax blog /whisperkit: no iPhone numbers. /apple-neural-engine-whisper: HTTP 404.
- NOT FOUND: Argmax-published real-time factor, tokens/s and absolute memory for Whisper models on iPhone 15 Pro, 16 Pro, 17 Pro (only "Speed Factor of 10 ... up from 4" for iPhone 17 Air, uncompressed turbo; raw performance_data.json unread).

## Fact 5 - Whisper Arabic WER
- Source: Radford et al., "Robust Speech Recognition via Large-Scale Weak Supervision" (OpenAI, 2022). paper. URL https://ar5iv.labs.arxiv.org/html/2212.04356 (appendix, read at offset 100000). Reached: fetch of ar5iv version.
  - Table 11 "WER (%) on CommonVoice9", Arabic: tiny 90.9, base 84.4, small 66.4, medium 60.3, large 56.0, large-v2 53.8.
  - Table 13 "WER (%) on Fleurs", Arabic: tiny 63.4, base 48.8, small 30.6, medium 20.4, large 18.1, large-v2 16.0.
  - FLEURS language ID, Table 5: zero-shot Whisper 64.5 overall accuracy; "no Arabic-specific accuracy appears" in fetched text. (fetch-tool wording: reaches 80.3% on 82 overlapping languages.) Numbers are fetch-tool extractions, not raw table views.
- Source: Talafha et al., "N-Shot Benchmarking of Whisper on Diverse Arabic Speech Recognition" (arXiv 2306.02902, 2023). paper. URL https://ar5iv.labs.arxiv.org/html/2306.02902. Reached: search "whisper ArzEn-ST OR MGB-3 OR CALLHOME Egyptian ...", then ar5iv. PDF fetch was unreadable.
  - Abstract excerpt: "its performance deteriorates significantly in the zero-shot setting for five unseen dialects"
  - WER table (Large-v2 zero-shot / Large-v2 full FT / Small full FT): CV6.1 15.93/10.81/22.21; CV9.0 19.2/12.97/24.61; CV11.0 19.41/13.28/24.12; FLEURS 11.56/10.36/23.76; MGB-2 34.74/15.49/29.66; "MGB-3 (Egyptian)" 43.53/31.39/49.68; MGB-5 (Moroccan) 82.97/53.82/73.98.
  - Unseen dialect zero-shot (Large-v2): Algeria 103.44, Jordan 72.80, Palestine 51.92, UAE 102.83, Yemen 102.66.
  - Fetch caveat: source text inconsistent on MGB-3 (text calls 31.39 the zero-shot WER; Table 1 lists it as large full-FT). Unresolved.
  - Language ID: "Namely, Whisper is trained on ASR, voice activity detection, language identification, and speech translation." No LID findings.
- Source: Casablanca: Data and Models for Multidialectal Arabic Speech Recognition (arXiv 2410.04527). paper. URL https://arxiv.org/html/2410.04527. Reached: search result, html fetch.
  - Table 3, Whisper large-v3 on Egyptian, WER / CER: "59.11 / 24.77" without preprocessing, "48.95 / 19.86" with preprocessing (fetch-tool extraction; column identity as Egyptian per tool).
  - Section 7.2 fragment: "whisper-egyptian on MGB-3 focused on the Egyptian dialect". 
- Source: Zero-Shot Context-Aware ASR for Diverse Arabic Varieties (arXiv 2511.18774), search summary only, not opened: zero-shot Whisper-large-v3 MSA WER "15.55% on CV15 and 16.02% on MGB-2"; "sometimes hallucinated generic filler content".
- NOT FOUND: Whisper WER on CALLHOME Egyptian and ArzEn-ST. Searched: "whisper ArzEn-ST OR MGB-3 OR CALLHOME Egyptian Whisper large-v3 WER evaluation" (no results for those two corpora in result snippets). No Whisper large-v3 or turbo specific MGB-3 number found beyond Casablanca.

## Fact 7 - Language ID (mixed English/Arabic)
- Source: openai/whisper transcribe.py (OpenAI). repo (code). URL https://raw.githubusercontent.com/openai/whisper/main/whisper/transcribe.py. Reached: direct fetch.
  - "_, probs = model.detect_language(mel_segment)"; "decode_options["language"] = max(probs, key=probs.get)"; "mel_segment = pad_or_trim(mel, N_FRAMES)"; verbose message "Detecting language using up to the first 30 seconds."
  - Fetch-tool reading: detection runs once before the sliding-window loop; same language used for every window of the file.
- Source: argmaxinc/WhisperKit TranscribeTask.swift (main). repo (code). URL https://raw.githubusercontent.com/argmaxinc/WhisperKit/main/Sources/WhisperKit/Core/TranscribeTask.swift. Reached: direct fetch.
  - "// For a multilingual model, if language is not passed and detectLanguage is true, detect language and set in options"; guard "if textDecoder.isModelMultilingual, options.language == nil, options.detectLanguage {" located inside `decodeWithFallback`; "let languageDecodingResult: DecodingResult? = try? await textDecoder.detectLanguage("
  - Fetch-tool reading: detection appears to run per window (and per temperature fallback attempt). Result level only: "language: detectedLanguage ?? Constants.defaultLanguageCode," returns one language per TranscriptionResult; TranscriptionSegment definition not in the excerpt, no per-segment language field shown. (Interpretation by fetch tool; needs confirmation from raw file.)
- Source: WhisperKit PR #146 (Argmax). repo. URL https://github.com/argmaxinc/WhisperKit/pull/146/files. Reached: search "WhisperKit detectLanguage per window code-switching ...".
  - "public func detectLanguage(audioPath: String) async throws -> (language: String, langProbs: [String: Float])"; comment "// Detect language using up to the first 30 seconds".
- Source: HF forum thread "Whisper for Arabic-English speech with Indian accent", user John6666 reply, 3 Feb 2026. forum-anecdote. URL https://discuss.huggingface.co/t/whisper-for-arabic-english-speech-with-indian-accent/173020. Reached: search "Whisper language identification accuracy Arabic dialects Egyptian misidentified code-switching English Arabic".
  - "language detection is performed using the first ~30 seconds" ; "Auto-LID being computed on the first ~30s is a known limitation"; code-switching "breaks the model's strongest assumptions". Suggests forcing language for two passes (Arabic and English).
- Source: Casablanca (arXiv 2410.04527), search-summary only: Whisper "never produced code-switched words in any decoding setting"; with English set it "translated rather than transcribed", with Auto or Arabic it output "only transliterations" (summary wording, not verified in text). paper.
- Source: convertaudiototext.com/blog/fix-multilingual-code-switching (blog, search summary only): no language setting lets Whisper estimate language per 30-second window. forum-anecdote class. Conflicts with openai/whisper transcribe.py reading above (once per file).
- NOT FOUND: any measurement of Whisper language-ID accuracy on Arabic dialects (Egyptian) or on Egyptian-English mixing. Searched: "Whisper language identification accuracy Arabic dialects Egyptian misidentified code-switching English Arabic"; WhisperKit GitHub issue search via "WhisperKit detectLanguage per window code-switching language detection segment github issue". FLEURS LID Table 5 gives no Arabic row in fetched text.

## Fact 4 addenda (more HF models, search-result level only, model cards NOT opened)
- ahmedsamirio/whisper_large_v3_turbo_common_voice_arzen_{32_bs_10000_steps, 48_bs_1000_steps, 48_bs_3000_steps, 48_bs_5000_steps, 64_bs_5000_steps, arzen_5000_steps, 32_bs_10000_steps_log_checkpoint_7000 "Updated Nov 4, 2024"}. URLs e.g. https://huggingface.co/ahmedsamirio/whisper_large_v3_turbo_common_voice_arzen_64_bs_5000_steps ; profile https://huggingface.co/ahmedsamirio . Reached: search "huggingface whisper-large-v3-turbo arzen egyptian common voice ahmedsamirio". Search-tool summary: "Most of the pages I saw have no model card"; ~809M params. Base: turbo per name. WER: none seen. License: not seen. model-card (absent).
- zainab11/whisper-small-ar-fleurs - https://huggingface.co/zainab11/whisper-small-ar-fleurs (mirror https://friendli.ai/models/zainab11/whisper-small-ar-fleurs). Search summary only: Whisper Small fine-tuned on Egyptian Arabic FLEURS; "normalized WER of about 19.9% on the test split, down from a 28.0% baseline"; heading "Results (FLEURS ar_eg test, 427 samples, corpus-level)". Not opened.
- dev-ahmedhany/whisper-large-v3-turbo-arabic-ft-lora, YazanSalameh/Whisper-base-Arabic, Marialab/whisper-large-v3-turbo-parameterized-gelu: appeared in results, not opened, Egyptian status unknown.
- Search queries used: "whisper egyptian arabic fine-tuned huggingface"; "huggingface whisper masri OR arz OR "egyptian" ASR model WER ArzEn"; "whisper ArzEn-ST OR MGB-3 OR CALLHOME ...". Not searched separately: "whisper masri" alone, "whisper MGB-3" alone, "whisper dialectal arabic" alone.

## Fact 5/8 addenda - other papers
- Source: "Dialectal Coverage And Generalization in Arabic Speech Recognition" (ArTST-related, arXiv 2411.05872v3). paper. URL https://arxiv.org/html/2411.05872v3. Reached: search result. 
  - Table 3 row (fetch extraction): "Whisper | ComVoice | MGB3 | 39.04 | 24.92" (AV-WER / MR-WER on MGB-3 Egyptian); Whisper variant not specified; row is a fine-tuned/adapted comparison per tool reading (columns adaptation data, fine-tuning data). Others on MGB-3: Aalto 37.50/29.30; ArTST v1 37.08/29.39; ArTST v2 33.20/25.28; MMS 100.04/99.92.
  - ArzEn (Table 11, ArTST only): v1 43.21, v2 77.59, v3 35.26 direct fine-tune; with adaptation 34.85, 33.71, 27.43. "The page reports no Whisper result on ArzEn." CALLHOME: not mentioned.
- Source: ArzEn-LLM (arXiv 2406.18120). paper. URL https://arxiv.org/pdf/2406.18120. PDF fetch unreadable. Search summary only: uses Whisper for ASR on ArzEn-ST; WER numbers not seen. Not read.
- Source: Open Universal Arabic ASR Leaderboard (arXiv 2412.13788), "Overcoming Data Scarcity in Multi-Dialectal Arabic ASR via Whisper Fine-Tuning" (arXiv 2506.02627): URLs appeared in search, NOT opened. SADA dataset dialect table mentioned in search summary.
- Fact 8: NOT FOUND: a blog, paper or issue publishing Whisper large-v3 or turbo transcripts or numbers on Egyptian conversational speech. Closest: Casablanca Table 3 (large-v3, Egyptian 59.11/24.77 raw, 48.95/19.86 preprocessed; test-set character not verified) and Dr-AliGomaa card (fine-tune, not base). Searched: "Whisper large-v3 turbo Egyptian Arabic conversational speech transcription test results blog" (only model listings returned); "whisper ArzEn-ST OR MGB-3 OR CALLHOME Egyptian Whisper large-v3 WER evaluation". GitHub issues/discussions not searched directly.

## Fact 6 - Alternatives (all entries: evidence of Arabic / evidence of iOS)
- sherpa-onnx. Source: sherpa-onnx docs, k2-fsa. vendor-doc. URL https://k2-fsa.github.io/sherpa/onnx/moonshine/models-v2.html. Reached: search "sherpa-onnx pretrained models Arabic ASR iOS".
  - Arabic: "sherpa-onnx-moonshine-base-ar-quantized-2026-02-27"; "This model supports only `Arabic`." Files: decoder_model_merged.ort 105M, encoder_model.ort 30M, total 135M. No WER on the page. Sample: "Decoding took 1.003 s for 6.546 s of audio, an RTF of 0.153" (CPU, 2 threads, on unspecified desktop machine).
  - iOS: this page documents Android APK and desktop CLI only; iOS not mentioned there. Search summary: sherpa-onnx lists iOS among platforms; no Arabic model confirmed on iOS. Other sherpa-onnx Arabic models (e.g. Whisper exports, NeMo): NOT FOUND, not searched individually.
- Moonshine (Useful Sensors / Moonshine AI) Arabic: only the sherpa-onnx packaging above found. NOT FOUND: Moonshine model card, Arabic WER, Egyptian evaluation, iOS Arabic. Searched: "Moonshine Arabic model release WER Egyptian FLEURS Moonshine Flavors multilingual" (returned unrelated results).
- NVIDIA Parakeet / Canary. Search summary only (not opened): Canary-1b-v2 and Parakeet v3 described as "25 European languages" (Arabic not in set); "Riva Canary-0.6B-Turbo model supports automatic speech-to-text recognition (ASR) and automatic speech-to-text-translation (AST) in following languages: Arabic (ar-AR)" (NVIDIA build.nvidia.com / NGC catalog, vendor-doc, URL https://build.nvidia.com/nvidia/canary-0-6b-turbo-asr/modelcard). A third-party listing claims Parakeet 1.1B covers Arabic (conflicts; treated as unreliable by summary). NVIDIA forum thread March 2026 "Arabic Language Support in Parakeet-RNNT Multilingual ASR" seen in title only. iOS: Argmax runs Parakeet v2/v3 on iPhone (Argmax blog, see Fact 2: Parakeet v3 "0.6 billion parameter", "sub-second latency"); no iOS evidence for Canary Riva turbo. Query: "NVIDIA Canary Parakeet Arabic support languages Parakeet v3 25 European languages Canary-1b-v2 Arabic".
- Vosk Arabic: NOT FOUND: size, WER, iOS build for vosk-model-ar-mgb2. Searched: "Vosk model Arabic vosk-model-ar-mgb2 WER size iOS" (only generic Vosk pages; secondary claim "iOS по запросу" i.e. iOS on request). alphacephei.com/vosk/models not fetched.
- Kyutai STT. Source: Kyutai blog, vendor-doc. URL https://kyutai.org/2025/06/19/stt-open-source.html. Search snippet: "kyutai/stt-1b-en_fr, a low-latency model that understands English and French"; "kyutai/stt-2.6b-en, a larger English-only model". No Arabic. iOS: not found.
- SeamlessM4T on device: NOT FOUND. Searched: "Kyutai STT supported languages; SeamlessM4T on-device iPhone Core ML Arabic" (no Seamless results). 
- Apple SpeechAnalyzer / SpeechTranscriber (iOS 26). Source: Apple docs and developer forums via search. Reached: search "Apple SpeechAnalyzer SpeechTranscriber supported locales Arabic ar_EG iOS 26".
  - Forum anecdote (Apple Developer Forums, thread 797835 and a thread by an unnamed poster): SpeechTranscriber "erroneously listed Arabic as 'supported'. It actually wasn't." and "Arabic worked in iOS 26.0" (search summary; thread not opened; contradictory). Blog launch list excludes Arabic: "Cantonese, Chinese, English, French, German, Italian, Japanese, Korean, Portuguese and Spanish" (blog.addpipe.com, third-party). Apple thread 806765 (opened): OP Nov '25 "I've also checked the supportedLocales, and the value is an empty array." no Arabic mention.
  - NOT FOUND: Apple's own authoritative locale list for SpeechTranscriber / DictationTranscriber / SFSpeechRecognizer ar-EG. Egyptian-dialect (ar_EG) specifically: not found.

## Summary of NOT FOUND (consolidated)
- NOT FOUND: Fact 1 on-device translate task in WhisperKit Swift API (only server endpoint; DecodingOptions task not checked in source). Searched: argmaxinc/WhisperKit README, argmax-oss-swift README, HF whisperkit-coreml.
- NOT FOUND: Fact 1 distil variant list (only a CLI example "--model "large-v3" --model-prefix "distil""). Turbo build names found: large-v3-v20240930_turbo, large-v3-v20240930_626MB.
- NOT FOUND: Fact 2 iPhone 15/16/17 Pro RTF/tokens/s/memory for Whisper (see Fact 2 section).
- NOT FOUND: Fact 3 explicit statement on custom fine-tuned checkpoints beyond the README lines; no listed constraints on architecture/size. Conversion requires macOS/Xcode (coremlcompiler).
- NOT FOUND: Fact 5 CALLHOME Egyptian / ArzEn-ST Whisper numbers.
- NOT FOUND: Fact 7 LID accuracy measurement on Arabic dialects.
- NOT FOUND: Fact 8.
- NOT FOUND: Fact 6 Vosk Arabic, SeamlessM4T on-device, Apple authoritative locale list.
- Web budget: exceeded ~30 (about 40 fetch/search calls). Many items are search-tool summaries, flagged as such.
