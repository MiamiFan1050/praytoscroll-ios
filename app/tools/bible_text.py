#!/usr/bin/env python3
"""Public-domain Bible text by reference, from ebible.org's verse-per-line files.

    tools/bible_text.py kjv <eng-kjv_vpl.txt>      # fills "kjv" for every verse in verses.json
    tools/bible_text.py check <engwebp_vpl.txt>    # reports verses.json WEB text that differs from ebible's WEB

Download (both public domain): https://ebible.org/Scriptures/eng-kjv_vpl.zip and engwebp_vpl.zip.
KJV note: public domain everywhere except the UK, where the Crown's letters patent cover printed copies.
"""
import json
import re
import sys
from pathlib import Path

BOOKS = {
    "Genesis": "GEN", "Exodus": "EXO", "Leviticus": "LEV", "Numbers": "NUM", "Deuteronomy": "DEU", "Joshua": "JOS",
    "Judges": "JDG", "Ruth": "RUT", "1 Samuel": "1SA", "2 Samuel": "2SA", "1 Kings": "1KI", "2 Kings": "2KI",
    "1 Chronicles": "1CH", "2 Chronicles": "2CH", "Ezra": "EZR", "Nehemiah": "NEH", "Esther": "EST", "Job": "JOB",
    "Psalm": "PSA", "Psalms": "PSA", "Proverbs": "PRO", "Ecclesiastes": "ECC", "Song of Solomon": "SOL",
    "Isaiah": "ISA", "Jeremiah": "JER", "Lamentations": "LAM", "Ezekiel": "EZE", "Daniel": "DAN", "Hosea": "HOS",
    "Joel": "JOE", "Amos": "AMO", "Obadiah": "OBA", "Jonah": "JON", "Micah": "MIC", "Nahum": "NAH",
    "Habakkuk": "HAB", "Zephaniah": "ZEP", "Haggai": "HAG", "Zechariah": "ZEC", "Malachi": "MAL",
    "Matthew": "MAT", "Mark": "MAR", "Luke": "LUK", "John": "JOH", "Acts": "ACT", "Romans": "ROM",
    "1 Corinthians": "1CO", "2 Corinthians": "2CO", "Galatians": "GAL", "Ephesians": "EPH", "Philippians": "PHI",
    "Colossians": "COL", "1 Thessalonians": "1TH", "2 Thessalonians": "2TH", "1 Timothy": "1TI", "2 Timothy": "2TI",
    "Titus": "TIT", "Philemon": "PHM", "Hebrews": "HEB", "James": "JAM", "1 Peter": "1PE", "2 Peter": "2PE",
    "1 John": "1JO", "2 John": "2JO", "3 John": "3JO", "Jude": "JUD", "Revelation": "REV",
}
REF = re.compile(r"^(?P<book>.+?) (?P<ch>\d+):(?P<v1>\d+)(?:-(?P<v2>\d+))?$")


def load(path):
    table = {}
    for line in Path(path).read_text(encoding="utf-8").splitlines():
        m = re.match(r"^(\S+) (\d+):(\d+) (.*)$", line)
        if m:
            table[(m[1], int(m[2]), int(m[3]))] = m[4]
    return table


def clean(text, kjv):
    text = text.replace("¶", "").strip()
    if kjv:
        text = re.sub(r"\[([^\]]*)\]", r"\1", text)   # KJV italics (supplied words) as plain text
    return re.sub(r"\s+", " ", text)


def passage(table, ref, kjv=False):
    m = REF.match(ref)
    if not m or m["book"] not in BOOKS:
        raise ValueError(f"can't read reference {ref!r}")
    code, ch, v1 = BOOKS[m["book"]], int(m["ch"]), int(m["v1"])
    v2 = int(m["v2"] or v1)
    parts = []
    for v in range(v1, v2 + 1):
        if (code, ch, v) not in table:
            raise ValueError(f"{ref}: verse {v} missing")
        parts.append(clean(table[(code, ch, v)], kjv))
    return " ".join(parts)


def main():
    mode, source = sys.argv[1], sys.argv[2]
    verses_path = Path(__file__).resolve().parent.parent / "PrayToScroll/Resources/verses.json"
    verses = json.loads(verses_path.read_text(encoding="utf-8"))
    table = load(source)
    if mode == "kjv":
        for verse in verses:
            verse["kjv"] = passage(table, verse["ref"], kjv=True)
        verses_path.write_text(json.dumps(verses, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print(f"kjv: {len(verses)} verses")
    elif mode == "check":
        for verse in verses:
            web = passage(table, verse["ref"])
            if web.strip("“”‘’ ") != verse["text"].strip("“”‘’ "):
                print(f'{verse["day"]} {verse["ref"]}\n  app: {verse["text"]}\n  web: {web}')
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main()
