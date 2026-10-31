"""Blind back-translation (D15): qwen3:8b sees only each arabic field, never the english or gloss.

Writes crosscheck_raw.tsv (id, first english alias, arabic, back-translation). Judging which rows
disagree in meaning is done by reading that table; the verdicts go to crosscheck.md.
"""
import json
import urllib.request
from pathlib import Path

MODEL = "qwen3:8b"
URL = "http://localhost:11434/api/chat"
HERE = Path(__file__).resolve().parent
PHRASEBOOK = HERE.parents[1] / "app" / "EgyptTalk" / "Resources" / "phrasebook.json"
OUT = HERE / "crosscheck_raw.tsv"

SYSTEM = ("You translate Egyptian Arabic (Cairo dialect) into English. Each line is something a man visiting his family in Cairo says to them, or to a driver or shopkeeper. When a line holds two forms "
          "separated by '/', they are the same phrase said to a man and to a woman; translate it once. "
          "'...' marks a blank the speaker fills in. Reply with only the English translation, on one line.")


def back_translate(arabic: str) -> str:
    body = {"model": MODEL, "stream": False, "think": False, "keep_alive": "10m",
            "options": {"temperature": 0, "num_predict": 80},
            "messages": [{"role": "system", "content": SYSTEM}, {"role": "user", "content": arabic}]}
    req = urllib.request.Request(URL, data=json.dumps(body).encode("utf-8"),
                                 headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=120) as resp:
        return json.loads(resp.read())["message"]["content"].replace("/no_think", "").strip().replace("\n", " ").replace("\t", " ")


entries = json.loads(PHRASEBOOK.read_text(encoding="utf-8"))["entries"]
rows = ["id\tenglish\tarabic\tback_translation"]
for e in entries:
    back = back_translate(e["arabic"])
    rows.append(f"{e['id']}\t{e['english'][0]}\t{e['arabic']}\t{back}")
    print(f"{e['id']:28} {e['english'][0]:32} -> {back}", flush=True)
OUT.write_text("\n".join(rows) + "\n", encoding="utf-8")
print(f"wrote {len(entries)} rows to {OUT}")
