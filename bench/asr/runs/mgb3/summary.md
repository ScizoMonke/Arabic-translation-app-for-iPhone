# Summary: mgb3

Normalization applied to BOTH reference and hypothesis before WER/CER: diacritics stripped (U+0610-061A, U+064B-065F, U+0670, U+06D6-06ED) and tatweel removed; alef variants آ أ إ ٱ -> ا; taa marbuta ة -> ه; alef maqsura ى -> ي; every Unicode punctuation (P*) and symbol (S*) character replaced by a space (this removes the reference's '...' turn separators); Latin lowercased; whitespace collapsed. Hamza carriers ؤ ئ are NOT unified. Digits are NOT spelled out (reference writes numbers as words, Whisper often writes digits, which counts as errors). Disfluency fragments in the reference (e.g. 'ال ال') are kept.
WER/CER are corpus-level (jiwer over all clips' word/char sequences pooled), not mean of per-clip values.
Instrument check this build: {'wer identical': 0.0, 'wer empty hyp': 1.0, 'cer identical': 0.0, 'cer empty hyp': 1.0, 'normalization makes variants equal': 0.0}

| run | task | WER | CER | empty outputs | audio s | wall s | audio s / wall s | backend |
|---|---|---|---|---|---|---|---|---|
| fw-large-v3-turbo-ct2-transcribe | transcribe | 0.376 | 0.204 | 0 | 747.02 | 41.63 | 17.94 | faster-whisper 1.2.1 |
| fw-large-v3-turbo-ct2-translate | translate | n/a; 0% of letters Latin | n/a; 0% of letters Latin | 0 | 747.02 | 44.01 | 16.98 | faster-whisper 1.2.1 |
| large-v3-transcribe | transcribe | 0.397 | 0.245 | 1 | 747.02 | 138.05 | 5.41 | faster-whisper 1.2.1 |
| large-v3-translate | translate | n/a; 100% of letters Latin | n/a; 100% of letters Latin | 0 | 747.02 | 78.4 | 9.53 | faster-whisper 1.2.1 |
| whisper-large-v3-arabic-transcribe | transcribe | 0.242 | 0.124 | 0 | 747.02 | 221.89 | 3.37 | transformers 5.5.0 |
| whisper-large-v3-egyptian-arabic-transcribe | transcribe | 0.387 | 0.230 | 0 | 747.02 | 272.86 | 2.74 | transformers 5.5.0 |
| whisper-small-eg-transcribe | transcribe | 0.760 | 0.414 | 0 | 747.02 | 98.28 | 7.6 | transformers 5.5.0 |

Wall time excludes one warm-up decode of the first clip. GPU: RTX 5070 Ti 16 GB. Settings per run in run_meta.json.