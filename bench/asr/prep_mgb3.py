# Extract ~30 evenly spaced clips (5-40 s) from one MGB-3 parquet shard into data/mgb3/clips.
# Reads untrusted data: run with `python -I`. Deterministic: same shard -> same clips.
import io, json, sys
from pathlib import Path
import pyarrow.parquet as pq
import soundfile as sf

sys.stdout.reconfigure(encoding="utf-8")
DATA = Path(r"C:\VScode\Arabic to English to Arabic IOS\data\mgb3")
SHARD = DATA / "data" / "train-00000-of-00002-69f2a5d14e629dff.parquet"
OUT = DATA / "clips"
N_CLIPS = 30

table = pq.read_table(SHARD)
rows = table.to_pylist()
cands = []
for i, r in enumerate(rows):
    audio, sr = sf.read(io.BytesIO(r["audio"]["bytes"]), dtype="float32")
    dur = len(audio) / sr
    if 5.0 <= dur <= 40.0 and r["sentence"].strip():
        cands.append((i, r, audio, sr, dur))
print("rows", len(rows), "candidates 5-40s with text", len(cands))
step = len(cands) / N_CLIPS
picked = [cands[int(k * step)] for k in range(N_CLIPS)]
OUT.mkdir(exist_ok=False)  # must be fresh; never overwrite
with open(DATA / "manifest.jsonl", "x", encoding="utf-8") as mf:
    for i, r, audio, sr, dur in picked:
        cid = f"mgb3_s0_r{i:04d}"
        if audio.ndim > 1:
            audio = audio.mean(axis=1)
        sf.write(OUT / f"{cid}.wav", audio, sr, subtype="PCM_16")
        mf.write(json.dumps({"clip_id": cid, "wav": str(OUT / f"{cid}.wav"), "duration": round(dur, 2),
                             "sr": sr, "src_path": r["audio"]["path"], "reference": r["sentence"]}, ensure_ascii=False) + "\n")
        print(cid, round(dur, 1), sr, r["audio"]["path"], r["sentence"][:60])
