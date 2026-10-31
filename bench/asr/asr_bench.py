# One ASR run: model x task x dataset -> runs/<dataset>/<model-short>-<task>/results.jsonl + run_meta.json.
# Usage (reads downloaded audio, so always isolated mode):
#   .venv/Scripts/python -I asr_bench.py <model_id> <transcribe|translate> <dataset>
# Backend: CT2 ids (OpenAI size names or repos with "ct2"/"faster-whisper") go through faster-whisper,
# anything else is treated as a PyTorch HF checkpoint and goes through the transformers pipeline.
import json, sys, time, platform
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8")
DATA_ROOT = Path(r"C:\VScode\Arabic to English to Arabic IOS\data")
RUNS = Path(__file__).resolve().parent / "runs"
CT2_SIZES = {"large-v3", "large-v2", "medium", "small", "base", "tiny", "large-v3-turbo", "turbo"}

model_id, task, dataset = sys.argv[1], sys.argv[2], sys.argv[3]
if task not in ("transcribe", "translate"):
    sys.exit(f"bad task {task!r}")
manifest = DATA_ROOT / dataset / "manifest.jsonl"
clips = [json.loads(l) for l in manifest.read_text(encoding="utf-8").splitlines() if l.strip()]
short = model_id.split("/")[-1].replace("faster-whisper-", "fw-")
use_ct2 = model_id in CT2_SIZES or "ct2" in model_id or "faster-whisper" in model_id

# Load the model BEFORE creating any output, so a bad id dies with no file written.
if use_ct2:
    from faster_whisper import WhisperModel
    import faster_whisper
    model = WhisperModel(model_id, device="cuda", compute_type="float16")
    def run(wav: str) -> str:
        # beam 5, language forced to Arabic: the app knows the speaker is Egyptian, LID is not under test here.
        segs, _ = model.transcribe(wav, language="ar", task=task, beam_size=5)
        return " ".join(s.text.strip() for s in segs).strip()
    settings = {"backend": "faster-whisper " + faster_whisper.__version__, "compute_type": "float16",
                "language": "ar", "beam_size": 5, "vad_filter": False}
else:
    import torch, transformers
    from transformers import pipeline
    pipe = pipeline("automatic-speech-recognition", model=model_id, torch_dtype=torch.float16, device="cuda:0")
    import soundfile as sf
    def run(wav: str) -> str:
        audio, sr = sf.read(wav, dtype="float32")
        out = pipe({"raw": audio, "sampling_rate": sr},
                   generate_kwargs={"language": "arabic", "task": task, "num_beams": 5})
        return out["text"].strip()
    settings = {"backend": "transformers " + transformers.__version__, "dtype": "float16",
                "language": "arabic", "num_beams": 5}

run(clips[0]["wav"])  # warm-up (CUDA init, kernel autotune) excluded from timing
out_dir = RUNS / dataset / f"{short}-{task}"
out_dir.mkdir(parents=True, exist_ok=True)
total_audio = total_wall = 0.0
with open(out_dir / "results.jsonl", "w", encoding="utf-8") as f:
    for c in clips:
        t0 = time.perf_counter()
        hyp = run(c["wav"])
        wall = time.perf_counter() - t0
        total_audio += c["duration"]; total_wall += wall
        rec = {"clip_id": c["clip_id"], "duration": c["duration"], "reference": c["reference"],
               "hypothesis": hyp, "wall_s": round(wall, 3)}
        f.write(json.dumps(rec, ensure_ascii=False) + "\n"); f.flush()
        print(c["clip_id"], f"{wall:.2f}s", hyp[:80])
meta = {"model_id": model_id, "task": task, "dataset": dataset, "n_clips": len(clips),
        "audio_s": round(total_audio, 2), "wall_s": round(total_wall, 2),
        "audio_s_per_wall_s": round(total_audio / total_wall, 2), "settings": settings,
        "python": platform.python_version(), "command": " ".join(sys.argv)}
(out_dir / "run_meta.json").write_text(json.dumps(meta, indent=2), encoding="utf-8")
print(json.dumps(meta))
