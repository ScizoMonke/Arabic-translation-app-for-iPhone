# Python twin of the app-5 rolling-window confirmation rule (Transcriber.swift
# StreamConfirmer + AppModel live loop), run with faster-whisper turbo on mgb3
# clips. Question it answers: does settling segments and advancing the window
# duplicate or drop words at the boundary, compared with one offline decode of
# the same clip? Each clip is treated as one continuous utterance (no energy
# gate), which is the hard case: the window must roll, not flush.
#
# Run: <bench venv python> -I stream_twin.py
import json
import re
import sys
import unicodedata
from pathlib import Path

import numpy as np
import soundfile as sf
from faster_whisper import WhisperModel

MANIFEST = Path(r"C:\VScode\Arabic to English to Arabic IOS\data\mgb3\manifest.jsonl")
OUT = Path(__file__).with_name("twin_results.jsonl")
SR = 16000

# Same constants as the Swift.
TICK_S = 1.0           # decode after this much new audio
MIN_WINDOW_S = 1.2     # WhisperKit windowClipTime is 1.0 s: shorter audio decodes nothing
AGE_S = 4.0            # a non-last segment ending this long before the window end settles anyway
FORCE_WINDOW_S = 24.0  # at this window length every non-last segment settles


def norm(text: str) -> str:
    # Agreement compares letters only: punctuation and spacing wobble between decodes.
    kept = [c for c in text if not unicodedata.category(c).startswith(("P", "Z", "S"))]
    return "".join(kept)


def words(text: str) -> list[str]:
    t = "".join(" " if unicodedata.category(c).startswith(("P", "S")) else c for c in text)
    t = re.sub(r"[\u064B-\u065F\u0670\u0640]", "", t)
    t = re.sub("[\u0622\u0623\u0625\u0671]", "\u0627", t).replace("\u0629", "\u0647").replace("\u0649", "\u064A")
    return t.split()


def decode(model: WhisperModel, audio: np.ndarray) -> list[tuple[str, float, float]]:
    segs, _ = model.transcribe(
        audio, language="ar", task="transcribe", beam_size=1, best_of=1,
        without_timestamps=False, condition_on_previous_text=False, vad_filter=False,
    )
    return [(s.text.strip(), float(s.start), float(s.end)) for s in segs if s.text.strip()]


def confirm(current, previous, window_s, flush):
    """Number of leading segments of `current` that settle."""
    if flush:
        return len(current)
    n = 0
    for i, (text, start, end) in enumerate(current[:-1]):  # never the last segment
        stable = i < len(previous) and norm(previous[i][0]) == norm(text)
        old = window_s - end >= AGE_S
        forced = window_s >= FORCE_WINDOW_S
        if stable or old or forced:
            n = i + 1
        else:
            break
    return n


def stream(model, audio):
    base = 0                 # absolute sample index of the window start
    previous = []            # previous decode of the same window (same base)
    settled = []             # (text, abs_start_s)
    decoded_upto = 0
    decodes = 0
    pos = 0
    total = len(audio)
    while True:
        pos = min(total, pos + int(0.1 * SR))     # 100 ms polling, as the Swift loop
        at_end = pos >= total
        window = audio[base:pos]
        window_s = len(window) / SR
        if not at_end and (window_s < MIN_WINDOW_S or (pos - decoded_upto) < TICK_S * SR):
            continue
        decoded_upto = pos
        segs = decode(model, window) if window_s >= MIN_WINDOW_S else []
        decodes += 1
        n = confirm(segs, previous, window_s, flush=at_end)
        for text, start, _ in segs[:n]:
            settled.append((text, base / SR + start))
        if n and not at_end:
            # Advance to the start of the first unsettled segment.
            cut = max(segs[n - 1][2], segs[n][1])  # as the Swift: never before the settled end
            base += int(round(cut * SR))
            previous = [(t, s - cut, e - cut) for t, s, e in segs[n:]]
        else:
            previous = segs
        if at_end:
            break
    return settled, decodes


def wer(ref: list[str], hyp: list[str]) -> float:
    d = np.zeros((len(ref) + 1, len(hyp) + 1), dtype=int)
    d[:, 0] = range(len(ref) + 1)
    d[0, :] = range(len(hyp) + 1)
    for i in range(1, len(ref) + 1):
        for j in range(1, len(hyp) + 1):
            d[i, j] = min(d[i - 1, j] + 1, d[i, j - 1] + 1, d[i - 1, j - 1] + (ref[i - 1] != hyp[j - 1]))
    return d[len(ref), len(hyp)] / max(1, len(ref))


def main() -> None:
    limit = int(sys.argv[1]) if len(sys.argv) > 1 else 30
    model = WhisperModel("deepdml/faster-whisper-large-v3-turbo-ct2", device="cuda", compute_type="float16")
    rows = [json.loads(l) for l in MANIFEST.read_text(encoding="utf-8").splitlines() if l.strip()][:limit]
    totals = {"ref_words": 0, "off_err": 0.0, "str_err": 0.0, "str_vs_off_err": 0.0, "off_words": 0,
              "boundaries": 0, "dup_boundaries": 0}
    with OUT.open("w", encoding="utf-8") as out:
        for row in rows:
            audio, sr = sf.read(row["wav"], dtype="float32")
            assert sr == SR
            offline = " ".join(t for t, _, _ in decode(model, audio))
            settled, decodes = stream(model, audio)
            streamed = " ".join(t for t, _ in settled)
            ref_w, off_w, str_w = words(row["reference"]), words(offline), words(streamed)
            # Boundary duplicate: the last word of one settled piece repeats as the first of the next.
            dups = 0
            for (a, _), (b, _) in zip(settled, settled[1:]):
                wa, wb = words(a), words(b)
                if wa and wb and wa[-1] == wb[0]:
                    dups += 1
            totals["ref_words"] += len(ref_w)
            totals["off_words"] += len(off_w)
            totals["off_err"] += wer(ref_w, off_w) * len(ref_w)
            totals["str_err"] += wer(ref_w, str_w) * len(ref_w)
            totals["str_vs_off_err"] += wer(off_w, str_w) * len(off_w)
            totals["boundaries"] += max(0, len(settled) - 1)
            totals["dup_boundaries"] += dups
            rec = {"clip": row["clip_id"], "dur": row["duration"], "decodes": decodes, "pieces": len(settled),
                   "wer_off": round(wer(ref_w, off_w), 3), "wer_stream": round(wer(ref_w, str_w), 3),
                   "stream_vs_off": round(wer(off_w, str_w), 3), "dup_boundaries": dups,
                   "len_off": len(off_w), "len_stream": len(str_w),
                   "offline_esc": offline.encode("unicode_escape").decode("ascii"),
                   "pieces_esc": [t.encode("unicode_escape").decode("ascii") for t, _ in settled]}
            out.write(json.dumps(rec) + "\n")
            print(row["clip_id"], {k: rec[k] for k in ("dur", "decodes", "pieces", "wer_off", "wer_stream",
                                                        "stream_vs_off", "dup_boundaries", "len_off", "len_stream")},
                  flush=True)
    t = totals
    print("SUMMARY", json.dumps({
        "clips": len(rows),
        "wer_offline_vs_ref": round(t["off_err"] / t["ref_words"], 3),
        "wer_stream_vs_ref": round(t["str_err"] / t["ref_words"], 3),
        "wer_stream_vs_offline": round(t["str_vs_off_err"] / max(1, t["off_words"]), 3),
        "boundaries": t["boundaries"], "dup_boundaries": t["dup_boundaries"],
    }))


if __name__ == "__main__":
    main()
