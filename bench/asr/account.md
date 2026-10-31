# ASR bench account (bench-1, 2026-10-31)

Dataset: MightyStudent/Egyptian-ASR-MGB-3, shard train-00000 (580 rows), 30 clips picked evenly by row index (rows 0,19,38,...,560), 15-29 s each, 747.02 s total.
Clips cover MGB-3 genres: comedy, cooking, family/kids talk show, fashion, movies/drama talk, science, sports. All are Egyptian TV/YouTube broadcast speech, not street conversation.
Data lives at C:\VScode\Arabic to English to Arabic IOS\data\mgb3 (parquet, README, clips\*.wav, manifest.jsonl).

## Results (corpus WER/CER after normalization; see runs/mgb3/summary.md for the exact rule)
| run | WER | CER | median clip WER | clips WER<=0.30 | audio s / wall s |
|---|---|---|---|---|---|
| large-v3-turbo (CT2) transcribe | 0.376 | 0.204 | 0.347 | 13/30 | 17.94 |
| large-v3 (CT2) transcribe | 0.397 | 0.245 | 0.336 | 13/30 | 5.41 |
| MightyStudent/whisper-large-v3-arabic | 0.242 | 0.124 | 0.206 | 23/30 | 3.37 |
| Dr-AliGomaa/whisper-large-v3-ar-eg | 0.326 | 0.165 | 0.280 | 17/30 | 3.17 |
| oddadmix/whisper-large-v3-arabic-dialectal-v2 | 0.363 | 0.197 | 0.303 | 14/30 | 2.85 |
| AbdelrahmanHassan/whisper-large-v3-egyptian-arabic (LoRA) | 0.387 | 0.230 | 0.270 | 17/30 | 2.74 |
| tawreck-hasaballah/whisper-small-eg | 0.760 | 0.414 | 0.516 | 1/30 | 7.60 |
| large-v3 translate | English, 100% Latin letters | | | | 9.53 |
| large-v3-turbo translate | Arabic, 0% Latin letters (turbo is not trained to translate) | | | | 16.98 |

Throughput is NOT a clean comparison: the GPU was shared with another agent's LLM bench (bench/llm/llm_bench.py, pid 15244 seen in nvidia-smi). gpu_before_load_mem_util in each run_meta.json shows the load seen at start; turbo transcribe ran at 26.97 x on an idle first run and 14.9-17.9 x on later reruns. CT2 and transformers backends differ too (CT2 float16 beam 5 with temperature fallback vs transformers fp16 beam 5 with no fallback).

## Clip to show the user: mgb3_s0_r0347 (26 s, drama scene, everyday dialogue)
large-v3 translate output: "We can help each other. How? If you don't mind, I can help you and you can write. That way we can both benefit. What did you say? Okay. Ibrahim, good morning. Good morning. Good morning."
Reference meaning (orchestrator's read needed): "No need to hold you up. On the contrary, we can help each other. How? If you don't mind, I can dictate to you and you write, that way we finish faster and we both benefit. What do you say? OK. Ibrahim, good morning..."
Why: short everyday turns like the ones he will hear. The gist comes through, but the first sentence is dropped and "dictate" turns into "help". That is about as good as this run gets.
Counter-example worth showing too: mgb3_s0_r0154, where "فساتين" (dresses) became "defects" in the English, and mgb3_s0_r0000, where large-v3 translate starts with "F**k" over what sounds like a show intro.

## Reproduce
cd bench/asr; .venv/Scripts/python -I prep_mgb3.py (refuses to run if data/mgb3/clips exists);
.venv/Scripts/python -I asr_bench.py <model_id> <transcribe|translate> mgb3;
.venv/Scripts/python -I build_report.py mgb3; .venv/Scripts/python -I per_clip_stats.py mgb3.
Determinism: before seeding, a turbo transcribe rerun differed on 1/30 clips (r0057, the temperature-fallback path). After ctranslate2.set_random_seed(0), two reruns matched on 30/30. All CT2 runs in runs/ are from the seeded driver. The transformers runs use beam search with no sampling and torch.manual_seed(0); I did not rerun them to prove determinism.
