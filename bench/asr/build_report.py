# Builds runs/<dataset>/side_by_side.md and summary.md from every run dir under runs/<dataset>/.
# Runs the instrument check first and refuses to write if it fails.
# Usage: .venv/Scripts/python -I build_report.py <dataset>
import json, re, sys, unicodedata
from pathlib import Path
import jiwer

sys.stdout.reconfigure(encoding="utf-8")
RUNS = Path(__file__).resolve().parent / "runs"

DIACRITICS = re.compile("[ؐ-ًؚ-ٰٟۖ-ۭـ]")  # harakat, tanween, shadda, sukun, dagger alef, Quranic marks, tatweel
def normalize(s: str) -> str:
    s = DIACRITICS.sub("", s)
    s = re.sub("[آأإٱ]", "ا", s)    # آ أ إ ٱ -> ا
    s = s.replace("ة", "ه")                      # ة -> ه
    s = s.replace("ى", "ي")                      # ى -> ي
    s = "".join(" " if unicodedata.category(ch).startswith(("P", "S")) else ch for ch in s)  # punctuation and symbols
    return " ".join(s.lower().split())

def wer(ref: str, hyp: str) -> float:
    return jiwer.wer(normalize(ref), normalize(hyp))

def cer(ref: str, hyp: str) -> float:
    return jiwer.cer(normalize(ref), normalize(hyp))

# Instrument check.
_r = "أنا كلامي كده واضح ... تمام"
checks = {"wer identical": wer(_r, _r), "wer empty hyp": wer(_r, ""), "cer identical": cer(_r, _r), "cer empty hyp": cer(_r, ""),
          "normalization makes variants equal": wer("إِحْنا رايحة", "احنا رايحه")}
print("instrument check:", checks)
assert checks == {"wer identical": 0.0, "wer empty hyp": 1.0, "cer identical": 0.0, "cer empty hyp": 1.0,
                  "normalization makes variants equal": 0.0}, checks

dataset = sys.argv[1]
root = RUNS / dataset
ORDER = ["fw-large-v3-turbo-ct2-transcribe", "fw-large-v3-turbo-ct2-translate", "large-v3-transcribe", "large-v3-translate"]
run_dirs = sorted((d for d in root.iterdir() if (d / "run_meta.json").exists()),
                  key=lambda d: (ORDER.index(d.name) if d.name in ORDER else len(ORDER), d.name))
runs = {}
for d in run_dirs:
    recs = [json.loads(l) for l in (d / "results.jsonl").read_text(encoding="utf-8").splitlines() if l.strip()]
    runs[d.name] = (json.loads((d / "run_meta.json").read_text(encoding="utf-8")), {r["clip_id"]: r for r in recs})

first = next(iter(runs.values()))[1]
lines = [f"# Side by side: {dataset}", "",
         f"{len(first)} clips. REF is the dataset's Arabic transcript. Every other line is raw model output from runs/{dataset}/<run>/results.jsonl.",
         "Per-clip WER (normalized, see summary.md) shown in brackets for transcribe runs.", ""]
for cid, c in first.items():
    lines += [f"## {cid} ({c['duration']} s)", "", f"- **REF**: {c['reference']}"]
    for name, (meta, recs) in runs.items():
        r = recs[cid]
        tag = f" [WER {wer(r['reference'], r['hypothesis']):.2f}]" if meta["task"] == "transcribe" else ""
        lines.append(f"- **{name}**{tag}: {r['hypothesis'] or '(empty output)'}")
    lines.append("")
(root / "side_by_side.md").write_text("\n".join(lines), encoding="utf-8")

s = [f"# Summary: {dataset}", "",
     "Normalization applied to BOTH reference and hypothesis before WER/CER: diacritics stripped (U+0610-061A, U+064B-065F, U+0670, U+06D6-06ED) and tatweel removed; "
     "alef variants آ أ إ ٱ -> ا; taa marbuta ة -> ه; alef maqsura ى -> ي; every Unicode punctuation (P*) and symbol (S*) character replaced by a space "
     "(this removes the reference's '...' turn separators); Latin lowercased; whitespace collapsed. Hamza carriers ؤ ئ are NOT unified. Digits are NOT spelled out "
     "(reference writes numbers as words, Whisper often writes digits, which counts as errors). Disfluency fragments in the reference (e.g. 'ال ال') are kept.",
     "WER/CER are corpus-level (jiwer over all clips' word/char sequences pooled), not mean of per-clip values.",
     f"Instrument check this build: {checks}", "",
     "| run | task | WER | CER | empty outputs | audio s | wall s | audio s / wall s | backend |", "|---|---|---|---|---|---|---|---|---|"]
for name, (meta, recs) in runs.items():
    refs = [r["reference"] for r in recs.values()]; hyps = [r["hypothesis"] for r in recs.values()]
    empties = sum(1 for h in hyps if not h.strip())
    if meta["task"] == "transcribe":
        w = f"{jiwer.wer([normalize(x) for x in refs], [normalize(x) for x in hyps]):.3f}"
        c = f"{jiwer.cer([normalize(x) for x in refs], [normalize(x) for x in hyps]):.3f}"
    else:
        # Translate output has no English reference; report what script it actually came out in instead.
        joined = "".join(hyps); ar = len(re.findall("[؀-ۿ]", joined)); la = len(re.findall("[A-Za-z]", joined))
        w = c = f"n/a; {100 * la / max(ar + la, 1):.0f}% of letters Latin"
    s.append(f"| {name} | {meta['task']} | {w} | {c} | {empties} | {meta['audio_s']} | {meta['wall_s']} | {meta['audio_s_per_wall_s']} | {meta['settings']['backend']} |")
s += ["", "Wall time excludes one warm-up decode of the first clip. GPU: RTX 5070 Ti 16 GB. Settings per run in run_meta.json."]
(root / "summary.md").write_text("\n".join(s), encoding="utf-8")
print("\n".join(s[-len(runs) - 3:]))
