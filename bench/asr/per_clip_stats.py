# Robustness view of each transcribe run: median per-clip WER, clips with a repetition loop or near-empty output.
# Usage: .venv/Scripts/python -I per_clip_stats.py <dataset>   (imports nothing from build_report so -I is safe)
import json, re, statistics, sys, unicodedata
from pathlib import Path
import jiwer
sys.stdout.reconfigure(encoding="utf-8")
DIAC = re.compile("[ؐ-ًؚ-ٰٟۖ-ۭـ]")
def norm(s):  # identical to build_report.normalize
    s = DIAC.sub("", s); s = re.sub("[آأإٱ]", "ا", s)
    s = s.replace("ة", "ه").replace("ى", "ي")
    s = "".join(" " if unicodedata.category(c).startswith(("P", "S")) else c for c in s)
    return " ".join(s.lower().split())
for d in sorted((Path(__file__).resolve().parent / "runs" / sys.argv[1]).iterdir()):
    if not d.name.endswith("-transcribe"): continue
    recs = [json.loads(l) for l in (d / "results.jsonl").read_text(encoding="utf-8").splitlines()]
    w = [jiwer.wer(norm(r["reference"]), norm(r["hypothesis"])) for r in recs]
    loops = [r["clip_id"] for r in recs if len(norm(r["hypothesis"]).split()) > 1.5 * len(norm(r["reference"]).split())]
    short = [r["clip_id"] for r in recs if len(norm(r["hypothesis"]).split()) < 0.25 * len(norm(r["reference"]).split())]
    gpu = json.loads((d / "run_meta.json").read_text(encoding="utf-8")).get("gpu_before_load_mem_util")
    print(f"{d.name}: median clip WER {statistics.median(w):.3f}; clips WER<=0.30: {sum(x <= 0.30 for x in w)}/30; hyp >1.5x ref words (repetition loop OR reference omits crosstalk; read the clip): {loops}; near-empty(<0.25x): {short}; gpu before: {gpu}")
