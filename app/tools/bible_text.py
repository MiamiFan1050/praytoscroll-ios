#!/usr/bin/env python3
"""Public-domain Bible text by reference, from ebible.org's verse-per-line files.

    tools/bible_text.py kjv <eng-kjv_vpl.txt>      # fills "kjv" for every verse in verses.json
    tools/bible_text.py check <engwebp_vpl.txt>    # reports verses.json WEB text that differs from ebible's WEB
    tools/bible_text.py advent <plan.json> <engwebp_vpl.txt> <eng-kjv_vpl.txt>   # writes Resources/advent.json
    tools/bible_text.py devotionals <devos.json> <engwebp_vpl.txt> <eng-kjv_vpl.txt>   # writes Resources/devotionals.json
    tools/bible_text.py scroll <engwebp_vpl.txt> <eng-kjv_vpl.txt>   # refills the Bible text in Resources/scroll.json

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


def _balance(text, open_mark, close_mark, is_close):
    opens, stray = [], []
    for i, ch in enumerate(text):
        if ch == open_mark:
            opens.append(i)
        elif ch == close_mark and is_close(text, i):
            if opens:
                opens.pop()
            else:
                stray.append(i)
    drop = {i for i in opens if i == 0} | {i for i in stray if i == len(text) - 1}
    body = "".join(ch for i, ch in enumerate(text) if i not in drop)
    return open_mark * sum(i not in drop for i in stray) + body + close_mark * sum(i not in drop for i in opens)


def balance_quotes(text):
    """A passage cut out of a longer speech can open a quote it never closes (or close one it never opened).
    A stray mark at the very start or end goes; any other gets its partner at the other end (as the daily verses do).
    Single quotes first (a ’ only closes a quote after punctuation; otherwise it's an apostrophe), then double."""
    text = _balance(text, "‘", "’", lambda t, i: i > 0 and t[i - 1] in ",.?!;:”")
    return _balance(text, "“", "”", lambda t, i: True)


def display_passage(table, ref, kjv=False):
    """A passage ready for a card: balanced quotes, a capital first letter, and "…" where it stops mid-sentence."""
    text = balance_quotes(passage(table, ref, kjv).strip())
    lead = len(text) - len(text.lstrip("“‘"))
    if text[lead:lead + 1].islower():
        text = text[:lead] + text[lead].upper() + text[lead + 1:]
    stripped = text.rstrip("”’")
    if stripped[-1:] in ",;:":
        text = stripped[:-1] + "…" + text[len(stripped):]
    return text


def scroll(path, web, kjv):
    """Scroll the Word extras: verse text (WEB + KJV), "Finish the verse" text, and each fact's verse."""
    data = json.loads(Path(path).read_text(encoding="utf-8"))
    for verse in data["verses"]:
        verse["text"] = display_passage(web, verse["ref"])
        verse["kjv"] = display_passage(kjv, verse["ref"], kjv=True)
    for item in data["finish"]:
        item["text"] = display_passage(web, item["ref"])
        body = item["text"].rstrip("”’.!?…")
        if not body.lower().endswith(item["answer"].lower()):
            sys.exit(f'{item["ref"]}: the answer "{item["answer"]}" isn\'t how the verse ends: …{item["text"][-50:]}')
    for fact in data["facts"]:
        fact["verseText"] = display_passage(web, fact["ref"])
    for text in [v["text"] for v in data["verses"]] + [f["text"] for f in data["finish"]]:
        if "Yahweh" in text:
            sys.exit('use the "LORD" edition of the WEB (engwebp)')
    Path(path).write_text(json.dumps(data, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    print(f'scroll: {len(data["verses"])} verses, {len(data["facts"])} facts, {len(data["whoSaid"])} who said, '
          f'{len(data["finish"])} finish, {len(data["reflect"])} questions')


def main():
    mode, source = sys.argv[1], sys.argv[2]
    verses_path = Path(__file__).resolve().parent.parent / "PrayToScroll/Resources/verses.json"
    if mode == "scroll":
        scroll(verses_path.parent / "scroll.json", load(source), load(sys.argv[3]))
        return
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
    elif mode == "devotionals":
        devos = json.loads(Path(source).read_text(encoding="utf-8"))
        web, kjv = load(sys.argv[3]), load(sys.argv[4])
        for devo in devos:
            devo["text"] = passage(web, devo["ref"]).strip()
            devo["kjv"] = passage(kjv, devo["ref"], kjv=True)
            if "Yahweh" in devo["text"]:
                sys.exit(f'{devo["ref"]}: use the "LORD" edition of the WEB (engwebp)')
        out = verses_path.parent / "devotionals.json"
        out.write_text(json.dumps(devos, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print(f"devotionals: {len(devos)}")
    elif mode == "advent":
        plan = json.loads(Path(source).read_text(encoding="utf-8"))
        web, kjv = load(sys.argv[3]), load(sys.argv[4])
        for day in plan:
            day["text"] = passage(web, day["ref"]).strip()
            day["kjv"] = passage(kjv, day["ref"], kjv=True)
            if "Yahweh" in day["text"]:
                sys.exit(f'{day["ref"]}: use the "LORD" edition of the WEB (engwebp)')
        out = verses_path.parent / "advent.json"
        out.write_text(json.dumps(plan, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print(f"advent: {len(plan)} days")
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main()
