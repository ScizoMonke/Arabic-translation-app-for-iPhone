"""Build app/EgyptTalk/Resources/phrasebook.json from entries.py; respelling comes only from respell.py."""
import json
from pathlib import Path

from entries import ENTRIES
from respell import respell

OUT = Path(__file__).resolve().parents[2] / "app" / "EgyptTalk" / "Resources" / "phrasebook.json"

entries = []
for eid, tag, english, arabic, arabizi, gloss in ENTRIES:
    entries.append({
        "id": eid,
        "english": english,
        "arabic": arabic,
        "arabizi": arabizi,
        "respelling": respell(arabizi),
        "gloss": gloss,
        "tags": [tag],
    })

OUT.write_text(json.dumps({"version": 1, "entries": entries}, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
print(f"wrote {len(entries)} entries to {OUT}")
