"""D20 respelling: the Latin line the user reads aloud, derived from arabizi and never typed by hand.

Rule (brief, D20): 2 and 3 become an apostrophe; 5 kh, 7 h, 8 gh, 9 s, 6 t, 4 th; everything else
kept; doubled apostrophes collapsed; an apostrophe at the start of a word is dropped.
"""
import re

DIGIT_MAP: dict[str, str] = {"2": "'", "3": "'", "5": "kh", "7": "h", "8": "gh", "9": "s", "6": "t", "4": "th"}


def respell(arabizi: str) -> str:
    out = "".join(DIGIT_MAP.get(ch, ch) for ch in arabizi)
    out = re.sub(r"'{2,}", "'", out)
    # "Start of a word" = not preceded by a letter; covers string start, spaces, "/" and "(".
    out = re.sub(r"(?<![A-Za-z])'", "", out)
    return out


if __name__ == "__main__":
    for sample in ["3ayez", "el7amdulillah", "da2ee2a", "saba7 el 5eir", "la2", "ma3a el salama", "ezzayak / ezzayek"]:
        print(f"{sample!r:28} -> {respell(sample)!r}")
