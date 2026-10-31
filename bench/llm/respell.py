"""Arabizi -> plain lowercase English respelling for a reader who knows no Arabic.

Rule (from the orchestrator's brief, 2026-10-31): 2 and 3 become an apostrophe (dropped at the start of a word),
5 -> kh, 7 -> h, 8 -> gh, 9 -> s, 6 -> t, 4 -> th; everything else kept; doubled apostrophes collapsed.
The apostrophe is a pause marker for the reader: a glottal stop or ayn is not something an English reader can
produce from letters, and silence there is closer than a guessed vowel.
"""
from __future__ import annotations

import re

DIGIT_MAP: dict[str, str] = {"2": "'", "3": "'", "5": "kh", "7": "h", "8": "gh", "9": "s", "6": "t", "4": "th"}


def respell(arabizi: str) -> str:
    s = "".join(DIGIT_MAP.get(ch, ch) for ch in arabizi.lower())
    s = re.sub(r"'{2,}", "'", s)
    # Word-initial apostrophe carries nothing a reader can act on ("3andi" -> "andi").
    s = re.sub(r"(^|[\s\-(\"])'+", r"\1", s)
    return s


if __name__ == "__main__":
    for x in ["ma3 el salama", "3andi soda3", "te2olha tany", "el7amdulellah", "5alas", "ba3den", "9aba7 el 5eir"]:
        print(f"{x!r} -> {respell(x)!r}")
