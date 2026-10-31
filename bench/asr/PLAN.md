# ASR bench plan (bench-1)
1. Data: first of MightyStudent/Egyptian-ASR-MGB-3, ahmedsamirtarjama/MBZUAI_ArzEn_wav, NightPrince/MasriSpeech-Test with audio+Arabic transcript; ~30 clips of 5-40 s into data/<dataset>/ (own empty dir, read with python -I).
2. One driver bench/asr/asr_bench.py (model id, task, dataset) -> runs/<dataset>/<model-short>-<task>/results.jsonl; faster-whisper for OpenAI models, transformers pipeline for PyTorch fine-tunes.
3. Instrument check first: WER(identical)=0, WER(empty hyp)=1, bogus model id fails loudly with no file.
4. Order: turbo transcribe+translate, large-v3 transcribe+translate, then asr.md section 4 Egyptian fine-tunes (transcribe), commit after each run.
5. build_report.py writes side_by_side.md and summary.md (WER/CER after stated Arabic normalization, audio s per wall s).
