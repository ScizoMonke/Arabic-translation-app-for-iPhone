"""Mechanical checks on phrasebook.json. Exit code 1 on any failure; prints every failure."""
import json
import re
import sys
from collections import Counter
from pathlib import Path

from respell import respell

PATH = Path(__file__).resolve().parents[2] / "app" / "EgyptTalk" / "Resources" / "phrasebook.json"
TAGS = {"greeting", "intro", "family", "smalltalk", "hospitality", "religious", "polite", "meta",
        "directions", "shopping", "health", "time", "practical", "goodbye"}
ARABIC = re.compile(r"[؀-ۿݐ-ݿࢠ-ࣿﭐ-﷿ﹰ-﻿]")
LATIN = re.compile(r"[A-Za-z]")
ARABIZI_OK = re.compile(r"^[a-z0-9 ?,'/()!.]+$")

data = json.loads(PATH.read_text(encoding="utf-8"))  # raises if invalid JSON
fails: list[str] = []
assert data["version"] == 1
entries = data["entries"]

for eid, n in Counter(e["id"] for e in entries).items():
    if n > 1:
        fails.append(f"duplicate id {eid}")
alias_owner: dict[str, str] = {}
for e in entries:
    eid = e["id"]
    if set(e) != {"id", "english", "arabic", "arabizi", "respelling", "gloss", "tags"}:
        fails.append(f"{eid}: keys {sorted(e)}")
    if not 3 <= len(e["english"]) <= 6:
        fails.append(f"{eid}: {len(e['english'])} aliases")
    for a in e["english"]:
        if a != a.lower():
            fails.append(f"{eid}: alias not lowercase {a!r}")
        if a != a.strip() or re.search(r"[.,!?;:]$", a):
            fails.append(f"{eid}: alias trailing punctuation/space {a!r}")
        if a in alias_owner:
            fails.append(f"{eid}: alias {a!r} also in {alias_owner[a]}")
        alias_owner[a] = eid
    for field in ("arabizi", "respelling", "gloss"):
        if ARABIC.search(e[field]):
            fails.append(f"{eid}: Arabic code point in {field}")
    if any(ARABIC.search(a) for a in e["english"]):
        fails.append(f"{eid}: Arabic code point in english")
    if LATIN.search(e["arabic"]):
        fails.append(f"{eid}: Latin letter in arabic")
    if not ARABIC.search(e["arabic"]):
        fails.append(f"{eid}: arabic field has no Arabic")
    if re.search(r"[ً-ْ]", e["arabic"]):
        fails.append(f"{eid}: arabic is vocalized")
    if not ARABIZI_OK.match(e["arabizi"]):
        fails.append(f"{eid}: arabizi has unexpected characters {e['arabizi']!r}")
    if e["respelling"] != respell(e["arabizi"]):
        fails.append(f"{eid}: respelling != respell(arabizi)")
    if re.search(r"\d", e["respelling"]):
        fails.append(f"{eid}: digit left in respelling")
    if not e["tags"] or any(t not in TAGS for t in e["tags"]):
        fails.append(f"{eid}: tags {e['tags']}")
    # A "masc / fem" arabizi must be explained in the gloss, or he cannot pick the right half.
    if " / " in e["arabizi"] and "woman" not in e["gloss"]:
        fails.append(f"{eid}: gendered arabizi without 'woman' in gloss")

print(f"{len(entries)} entries, {len(alias_owner)} aliases, tags: {dict(Counter(e['tags'][0] for e in entries))}")
for f in fails:
    print("FAIL", f)
print("ALL CHECKS PASS" if not fails else f"{len(fails)} FAILURES")
sys.exit(1 if fails else 0)
