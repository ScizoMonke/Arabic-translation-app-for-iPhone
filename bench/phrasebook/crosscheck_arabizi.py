"""Second view on the rows still disagreeing: back-translate the arabizi field (vowels written, so the
script homographs like mayya/meyya disappear). Same model, same blindness to english and gloss."""
import json
import urllib.request
from pathlib import Path

HERE = Path(__file__).resolve().parent
entries = {e["id"]: e for e in json.loads((HERE.parents[1] / "app/EgyptTalk/Resources/phrasebook.json").read_text(encoding="utf-8"))["entries"]}
flagged = [line.split(" | ")[0] for line in (HERE / "crosscheck.md").read_text(encoding="utf-8").split("## Fixed")[0].splitlines()
           if " | " in line and line.split(" | ")[0] in entries]
SYSTEM = ("You translate Egyptian Arabic written in Latin letters (Arabizi: 2 hamza, 3 ayn, 5 kh, 7 h, 8 gh, 9 s, 6 t) into English. "
          "Each line is something a man visiting his family in Cairo says to them, or to a driver or shopkeeper. When a line holds two "
          "forms separated by '/', they are the same phrase said to a man and to a woman; translate it once. Reply with only the English.")
rows = ["id\tarabizi\tback_translation"]
for eid in flagged:
    body = {"model": "qwen3:8b", "stream": False, "think": False, "options": {"temperature": 0, "num_predict": 80},
            "messages": [{"role": "system", "content": SYSTEM}, {"role": "user", "content": entries[eid]["arabizi"]}]}
    req = urllib.request.Request("http://localhost:11434/api/chat", data=json.dumps(body).encode(), headers={"Content-Type": "application/json"})
    back = json.loads(urllib.request.urlopen(req, timeout=120).read())["message"]["content"].replace("/no_think", "").strip().replace("\n", " ")
    rows.append(f"{eid}\t{entries[eid]['arabizi']}\t{back}")
    print(f"{eid:26} {entries[eid]['english'][0]:32} -> {back}", flush=True)
(HERE / "crosscheck_arabizi.tsv").write_text("\n".join(rows) + "\n", encoding="utf-8")
