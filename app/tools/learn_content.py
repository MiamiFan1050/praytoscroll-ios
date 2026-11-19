#!/usr/bin/env python3
"""Learn content (Resources/learn.json + the facts in scroll.json): look up, fill and verify the Bible text.

    tools/learn_content.py ref "John 3:16" <engwebp_vpl.txt>      # prints the WEB text of a reference
    tools/learn_content.py check <file.json> <engwebp_vpl.txt>     # verifies a learn file or a fragment of one
    tools/learn_content.py fill <engwebp_vpl.txt>                  # fills every verse card in Resources/learn.json
                                                                   # from the WEB, then verifies everything

Every Scripture quote must be the World English Bible ("LORD" edition, engwebp), word for word:
  * "verse" cards get their text from the reference (never typed by hand);
  * a `quote` field must appear, word for word, inside the WEB text of its `ref`;
  * any “curly-quoted” words inside our own writing must appear inside the WEB text of that item's `ref`.
Exit status 1 on any problem, so a mismatch fails the build. Download: https://ebible.org/Scriptures/engwebp_vpl.zip
"""
import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from bible_text import BOOKS, REF, display_passage, load, passage  # noqa: E402

RESOURCES = Path(__file__).resolve().parent.parent / "PrayToScroll/Resources"
LEARN = RESOURCES / "learn.json"
SCROLL = RESOURCES / "scroll.json"

CARD_KINDS = {"story", "why", "verse", "quiz", "recap"}
TRUE_FALSE = ["True", "False"]
# Copy rules: no price talk, no "blocker", no shame lines.
BANNED = ["blocker", "$", "price", "subscribe", "premium", "free trial", "you failed", "failure", "lazy",
          "lose your streak", "don’t break", "ashamed of yourself", "guilty", "should have", "you missed"]
LIMITS = {"story": 300, "why": 260, "recap": 150, "question": 130, "choice": 44, "explain": 220,
          "context": 150, "fact": 150, "place": 90, "when": 110, "part": 280, "prayer": 140, "title": 40}


class Checker:
    def __init__(self, web):
        self.web = web
        self.errors = []
        self.quotes = 0
        self.refs = 0

    def err(self, where, message):
        self.errors.append(f"{where}: {message}")

    # -- references and quotes --

    def text(self, ref, where):
        """The WEB text of a reference, or None (and an error) if it doesn't parse or isn't in the WEB."""
        if not isinstance(ref, str) or not REF.match(ref):
            self.err(where, f"reference {ref!r} doesn't parse (Book C:V or Book C:V-W)")
            return None
        if REF.match(ref)["book"] not in BOOKS:
            self.err(where, f"unknown book in {ref!r}")
            return None
        try:
            raw = passage(self.web, ref)
        except ValueError as problem:
            self.err(where, str(problem))
            return None
        self.refs += 1
        return raw

    @staticmethod
    def norm(s):
        return re.sub(r"\s+", " ", s.replace(" ", " ")).strip()

    def contains(self, haystack, quote):
        """Word for word: the quote sits inside the passage (a capital first letter and one trailing mark may differ)."""
        hay = self.norm(haystack)
        q = self.norm(quote).strip("“”‘’ ")
        if q.endswith("…"):
            q = q[:-1].rstrip()
        candidates = [q]
        if q and q[-1] in ".,;:!?":
            candidates.append(q[:-1])
        for c in candidates:
            if not c:
                continue
            if c in hay or (c[0].upper() + c[1:]) in hay or (c[0].lower() + c[1:]) in hay:
                return True
        return False

    def quote(self, quote, ref, where):
        raw = self.text(ref, where)
        if raw is None:
            return
        self.quotes += 1
        if not self.contains(raw, quote):
            self.err(where, f"quote isn't word for word the WEB of {ref}:\n      ours: {quote}\n      WEB:  {self.norm(raw)}")

    def prose(self, text, ref, where, field, limit=None):
        """Our own words: house style, the length cap, and any “quoted” words checked against the WEB."""
        if not isinstance(text, str) or not text.strip():
            self.err(where, f"{field} is empty")
            return
        if '"' in text or "'" in text:
            self.err(where, f"{field} has a straight quote (use “ ” and ’)")
        if "—" in text or " - " in text:
            self.err(where, f"{field} has a dash (house style: commas, colons or a new sentence)")
        low = text.lower()
        for word in BANNED:
            if word in low:
                self.err(where, f"{field} says {word!r}")
        if limit and len(text) > limit:
            self.err(where, f"{field} is {len(text)} chars (max {limit})")
        for segment in re.findall(r"“([^”]+)”", text):
            if ref is None:
                self.err(where, f"{field} quotes “{segment}” but has no ref to check it against")
            else:
                self.quote(segment, ref, f"{where} ({field})")

    def quiz(self, item, where):
        question = item.get("question")
        choices = item.get("choices") or []
        answer = item.get("answer")
        ref = item.get("ref")
        self.prose(question, ref, where, "question", LIMITS["question"])
        if not (2 <= len(choices) <= 4):
            self.err(where, f"{len(choices)} choices (2 to 4)")
        if len(set(c.lower() for c in choices)) != len(choices):
            self.err(where, "two choices are the same")
        if answer not in choices:
            self.err(where, f"the answer {answer!r} isn't one of the choices")
        is_tf = sorted(choices) == sorted(TRUE_FALSE)
        if isinstance(question, str) and not (question.endswith("?") or (is_tf and question.endswith("."))):
            self.err(where, "a question ends with ?, a true/false statement with .")
        for choice in choices:
            if not isinstance(choice, str) or not choice.strip():
                self.err(where, "empty choice")
                continue
            self.prose(choice, ref, where, "choice", LIMITS["choice"])
        if ref is None:
            self.err(where, "quiz has no ref")
        else:
            self.text(ref, where)
        self.prose(item.get("explain"), ref, where, "explain", LIMITS["explain"])

    # -- sections --

    def paths(self, paths, ids):
        for path in paths:
            pid = path.get("id", "?")
            for key in ("id", "title", "subtitle", "symbol"):
                if not path.get(key):
                    self.err(pid, f"path has no {key}")
            lessons = path.get("lessons") or []
            if not lessons:
                self.err(pid, "path has no lessons")
            for lesson in lessons:
                self.lesson(lesson, ids)

    def lesson(self, lesson, ids):
        lid = lesson.get("id", "?")
        if lid in ids:
            self.err(lid, "duplicate id")
        ids.add(lid)
        self.prose(lesson.get("title"), None, lid, "title", LIMITS["title"])
        if lesson.get("passage"):
            self.text(lesson["passage"], f"{lid} passage")
        else:
            self.err(lid, "no passage")
        self.prose(lesson.get("prayer"), None, lid, "prayer", LIMITS["prayer"])
        cards = lesson.get("cards") or []
        if not (5 <= len(cards) <= 8):
            self.err(lid, f"{len(cards)} cards (5 to 8)")
        kinds = [c.get("kind") for c in cards]
        if kinds[:1] != ["story"]:
            self.err(lid, "the first card is a story")
        if kinds[-1:] != ["recap"]:
            self.err(lid, "the last card is a recap")
        if "quiz" not in kinds:
            self.err(lid, "no quiz card")
        if "verse" not in kinds:
            self.err(lid, "no key verse card")
        for index, card in enumerate(cards):
            where = f"{lid} card {index + 1} ({card.get('kind')})"
            kind = card.get("kind")
            if kind not in CARD_KINDS:
                self.err(where, f"unknown kind {kind!r}")
                continue
            ref = card.get("ref")
            if kind == "verse":
                raw = self.text(ref, where)
                if raw is not None:
                    shown = display_passage(self.web, ref)
                    if card.get("text") not in (None, shown):
                        self.err(where, f"verse text isn't the WEB of {ref} (run fill)")
                    if len(shown) > 320:
                        self.err(where, f"key verse is {len(shown)} chars: pick a shorter reference")
                    if "Yahweh" in shown:
                        self.err(where, "use the LORD edition of the WEB (engwebp)")
                    self.quotes += 1
            elif kind == "quiz":
                self.quiz(card, where)
            else:
                if kind in ("story", "why") and not ref:
                    self.err(where, "needs a ref that supports it")
                if ref:
                    self.text(ref, where)
                self.prose(card.get("text"), ref, where, "text", LIMITS[kind])

    def daily(self, items, ids):
        for item in items:
            where = item.get("id", "?")
            if where in ids:
                self.err(where, "duplicate id")
            ids.add(where)
            self.quiz(item, where)

    def jesus_said(self, items, ids):
        for item in items:
            where = item.get("id", "?")
            if where in ids:
                self.err(where, "duplicate id")
            ids.add(where)
            quote = item.get("quote", "")
            if not (8 <= len(quote) <= 200):
                self.err(where, f"quote is {len(quote)} chars (8 to 200)")
            self.quote(quote, item.get("ref"), where)
            self.prose(item.get("context"), item.get("ref"), where, "context", LIMITS["context"])

    def places(self, items, ids):
        for item in items:
            where = item.get("id", "?")
            if where in ids:
                self.err(where, "duplicate id")
            ids.add(where)
            ref = item.get("ref")
            self.text(ref, where)
            self.prose(item.get("title"), ref, where, "title", LIMITS["title"])
            self.prose(item.get("place"), ref, where, "place", LIMITS["place"])
            self.prose(item.get("when"), ref, where, "when", LIMITS["when"])
            self.prose(item.get("text"), ref, where, "text", LIMITS["why"])

    def series(self, items, ids):
        for item in items:
            sid = item.get("id", "?")
            if sid in ids:
                self.err(sid, "duplicate id")
            ids.add(sid)
            self.prose(item.get("title"), None, sid, "title", LIMITS["title"])
            parts = item.get("parts") or []
            if not (3 <= len(parts) <= 6):
                self.err(sid, f"{len(parts)} parts (3 to 6)")
            for index, part in enumerate(parts):
                where = f"{sid} part {index + 1}"
                ref = part.get("ref")
                self.text(ref, where)
                self.prose(part.get("text"), ref, where, "text", LIMITS["part"])
                if index < len(parts) - 1:
                    self.prose(part.get("next"), None, where, "next", 90)

    def facts(self, items, ids):
        for item in items:
            where = item.get("id", "?")
            if where in ids:
                self.err(where, "duplicate id")
            ids.add(where)
            ref = item.get("ref")
            self.text(ref, where)
            text = item.get("text", "")
            self.prose(text, ref, where, "fact", LIMITS["fact"])
            if len(text) < 50:
                self.err(where, f"fact is {len(text)} chars (50 to 150)")

    def run(self, data):
        ids = set()
        if isinstance(data, list):
            data = {"lessons": data}
        self.paths(data.get("paths", []), ids)
        for lesson in data.get("lessons", []):
            self.lesson(lesson, ids)
        self.daily(data.get("daily", []), ids)
        self.jesus_said(data.get("jesusSaid", []), ids)
        self.places(data.get("places", []), ids)
        self.series(data.get("series", []), ids)
        self.facts(data.get("facts", []), ids)
        return ids


def fill(data, web):
    for path in data.get("paths", []):
        for lesson in path.get("lessons", []):
            for card in lesson.get("cards", []):
                if card.get("kind") == "verse":
                    card["text"] = display_passage(web, card["ref"])


def report(checker, label):
    for line in checker.errors:
        print("  ✗", line)
    status = "FAIL" if checker.errors else "OK"
    print(f"{label}: {status}, {checker.refs} references and {checker.quotes} Scripture quotes checked against the WEB, "
          f"{len(checker.errors)} problems")
    return 1 if checker.errors else 0


def main():
    if len(sys.argv) < 3:
        sys.exit(__doc__)
    mode = sys.argv[1]
    if mode == "ref":
        print(display_passage(load(sys.argv[3]), sys.argv[2]))
        return 0
    if mode == "check":
        web = load(sys.argv[3])
        data = json.loads(Path(sys.argv[2]).read_text(encoding="utf-8"))
        checker = Checker(web)
        checker.run(data)
        return report(checker, Path(sys.argv[2]).name)
    if mode == "fill":
        web = load(sys.argv[2])
        data = json.loads(LEARN.read_text(encoding="utf-8"))
        fill(data, web)
        LEARN.write_text(json.dumps(data, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
        checker = Checker(web)
        checker.run(data)
        # The feed's "Did you know" facts (scroll.json): references and any quoted words.
        facts = json.loads(SCROLL.read_text(encoding="utf-8")).get("facts", [])
        checker.facts(facts, set())
        counts = {
            "paths": len(data.get("paths", [])),
            "lessons": sum(len(p["lessons"]) for p in data.get("paths", [])),
            "cards": sum(len(l["cards"]) for p in data.get("paths", []) for l in p["lessons"]),
            "lesson quizzes": sum(1 for p in data.get("paths", []) for l in p["lessons"] for c in l["cards"] if c["kind"] == "quiz"),
            "daily": len(data.get("daily", [])), "jesusSaid": len(data.get("jesusSaid", [])),
            "places": len(data.get("places", [])), "series": len(data.get("series", [])),
            "series parts": sum(len(s["parts"]) for s in data.get("series", [])), "facts": len(facts),
        }
        print("learn.json:", ", ".join(f"{v} {k}" for k, v in counts.items()))
        return report(checker, "learn.json + scroll.json facts")
    sys.exit(__doc__)


if __name__ == "__main__":
    sys.exit(main() or 0)
