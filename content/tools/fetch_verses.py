#!/usr/bin/env python3
"""Build content/verses.json: 366 daily verses, World English Bible (US edition, public domain).
God's name, which the WEB prints as "Yahweh", is rendered "the LORD" (see render_divine_name;
credit line in copy.json: translationCredit). US spelling is kept.

Every verse text comes from https://bible-api.com/<ref>?translation=web. Nothing is typed
from memory. Raw API responses are cached in tools/cache/ so reruns cost no requests.

Usage:  python3 tools/fetch_verses.py          (from content/, or any cwd)

PLAN below lists the refs day by day, grouped into seasonal theme blocks so the year flows
(new year = purpose, Feb 14 inside love, Lent = focus + forgiveness, Easter = hope,
summer = rest, Thanksgiving = gratitude, Advent/Christmas = peace).
A line "A|B" means: use A, fall back to B. If a ref fails to fetch or fails a quality
check, the first passing ref from that theme's ALTERNATES is used instead, and the
substitution is printed.
"""
import json
import os
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
TRANSLATION = "web"  # cache/webbe/ keeps the British-edition responses from an earlier trial
CACHE = os.path.join(HERE, "cache", TRANSLATION)
OUT = os.path.join(os.path.dirname(HERE), "verses.json")
API = "https://bible-api.com/{}?translation=" + TRANSLATION
DELAY = 2.1          # seconds between network requests (bible-api allows ~15 per 30 s)
MAX_LEN = 320
TOTAL_DAYS = 366
BOOK_CAP = int(TOTAL_DAYS * 0.15)  # 54: no book above 15% of entries
THEMES = ["peace", "strength", "anxiety", "gratitude", "love", "purpose", "rest", "hope",
          "forgiveness", "courage", "focus", "identity", "provision", "community"]

PLAN = [
    ("purpose", """          # days 1-26: new year, calling
Isaiah 43:18-19
Jeremiah 29:11
Proverbs 3:5-6
Ephesians 2:10
Psalm 90:12
Philippians 3:13-14
Proverbs 16:3
Micah 6:8
Romans 8:28
Colossians 3:23-24
Psalm 37:4
Hosea 6:3
Matthew 5:14-16|Matthew 5:16
Proverbs 16:9
Philippians 2:13
1 Peter 4:10
Psalm 32:8
John 15:16
1 Corinthians 10:31
Isaiah 6:8
Proverbs 19:21
1 Timothy 4:12
Ecclesiastes 3:11
John 10:10
1 Thessalonians 5:24
Romans 12:1
"""),
    ("love", """             # days 27-52 (Feb 14 = day 45)
John 3:16
1 John 4:19
Jeremiah 31:3
Romans 5:8
1 Corinthians 16:14
Zephaniah 3:17
John 15:9
Psalm 63:3
1 John 4:7-8
Isaiah 49:15
Ephesians 5:2
John 13:34-35
Psalm 36:7
1 John 3:18
Romans 8:38-39
Proverbs 3:3
John 15:12-13
1 John 4:10
1 Corinthians 13:13
Romans 12:9
Colossians 3:14
Isaiah 54:10
1 Peter 4:8
Psalm 145:8-9
John 10:11
1 John 4:16
"""),
    ("focus", """            # days 53-78: self-control, attention (Lent)
Romans 12:2
Psalm 119:37
Proverbs 4:23
1 Corinthians 6:12
Matthew 6:6
Philippians 4:8
1 Corinthians 10:13
Colossians 3:2
Matthew 26:41
Galatians 5:22-23
Psalm 19:14
Ephesians 5:15-16
Proverbs 4:25-26
James 1:5
Matthew 6:22
Proverbs 16:32
1 Corinthians 9:24-25
Psalm 119:105
Galatians 5:16
James 1:19-20
Joshua 1:8
Mark 8:36
Proverbs 25:28
1 Peter 5:8
Hebrews 12:11
Psalm 139:23-24
"""),
    ("forgiveness", """      # days 79-104 (Lent / Holy Week)
1 John 1:9
Psalm 51:10
Isaiah 1:18
Ephesians 4:32
Psalm 103:12
Micah 7:18
Matthew 6:14
Romans 8:1
Isaiah 43:25
Luke 6:37
Psalm 86:5
Proverbs 28:13
Mark 11:25
Hebrews 4:16
Luke 15:20
Joel 2:13
Isaiah 44:22
Matthew 5:7
Proverbs 19:11
James 5:16
Psalm 51:12
Luke 6:36
Proverbs 10:12
Romans 4:7|Isaiah 38:17
John 3:17
Isaiah 53:5
"""),
    ("hope", """             # days 105-130 (Easter season)
Matthew 28:6
John 11:25-26
Job 19:25
1 Corinthians 15:57
Lamentations 3:22-23
Romans 15:13
Psalm 30:5
Revelation 21:5
Jeremiah 29:12-13
Hebrews 11:1
Romans 8:18
Psalm 42:11
Isaiah 40:8
John 14:2-3
Luke 1:37
Lamentations 3:24
Micah 7:7
Psalm 126:5
Jeremiah 17:7
2 Corinthians 4:16
Matthew 19:26
Proverbs 23:18
1 Corinthians 2:9
John 16:33
Psalm 27:13-14
Revelation 21:4
"""),
    ("identity", """         # days 131-156
2 Corinthians 5:17
Psalm 139:14
1 John 3:1
Galatians 2:20
1 John 3:2
John 15:15
Psalm 139:13
Galatians 3:26
Romans 8:37
Luke 12:7
Isaiah 43:1
John 15:5
1 Corinthians 6:19-20
Genesis 1:27
John 8:36
Psalm 100:3
Romans 8:15
Colossians 3:3
Isaiah 64:8
John 10:27-28
1 Corinthians 12:27
Galatians 5:1
1 Corinthians 3:16
2 Corinthians 3:18
John 1:12-13
Revelation 3:20
"""),
    ("rest", """             # days 157-182 (summer)
Matthew 11:28-30
Psalm 23:1-3
Exodus 33:14
Psalm 46:10
Mark 6:31
Psalm 62:1
Proverbs 3:24
Genesis 2:2-3
Psalm 127:2
Song of Solomon 2:11-12
Luke 10:41-42
Jeremiah 31:25
Psalm 4:8
Isaiah 40:11
Ecclesiastes 4:6
Luke 5:16
Exodus 14:14
Proverbs 19:23
Hebrews 4:9-10
Psalm 131:2
Mark 2:27
Isaiah 32:18
Lamentations 3:26
Proverbs 17:1
Matthew 14:23
Proverbs 15:16
"""),
    ("courage", """          # days 183-208
Joshua 1:9
Isaiah 41:10
Psalm 27:1
2 Timothy 1:7
Deuteronomy 31:8
Matthew 14:27
Romans 8:31
Psalm 56:3-4
Isaiah 43:2
Proverbs 29:25
Hebrews 13:6
1 Corinthians 16:13
Psalm 23:4
Isaiah 41:13
1 John 4:18
Isaiah 51:12
Deuteronomy 31:6
Psalm 118:6
Luke 12:32
Hebrews 10:35
Isaiah 50:7
1 John 4:4
Psalm 112:7
Proverbs 3:25-26
Matthew 17:7
Isaiah 44:8
"""),
    ("strength", """         # days 209-234
Philippians 4:13
Isaiah 40:31
Psalm 46:1
2 Corinthians 12:9
Isaiah 40:29
Ephesians 6:10
Psalm 121:1-2
Galatians 6:9
James 1:2-4
Proverbs 18:10
Psalm 73:26
1 Peter 5:10
Isaiah 40:28
2 Corinthians 4:7
Habakkuk 3:17-18
Psalm 28:7
Romans 8:26
2 Samuel 22:33
James 1:12
1 Chronicles 16:11
2 Corinthians 12:10
Proverbs 31:25
Isaiah 33:2
2 Thessalonians 3:3
2 Timothy 2:1
1 Corinthians 15:58
"""),
    ("anxiety", """          # days 235-260 (back to school / work)
Philippians 4:6-7
1 Peter 5:6-7
Psalm 55:22
Matthew 6:34
John 14:1
Psalm 94:19
Matthew 6:25
Jeremiah 33:3
Proverbs 12:25
Psalm 34:18
Mark 4:39
Isaiah 42:3
Matthew 6:27
Nahum 1:7
Hebrews 4:15
Psalm 61:2
John 14:18
2 Corinthians 1:3-4
Mark 9:24
Isaiah 46:4
1 John 5:14
Psalm 121:7-8
Lamentations 3:57
Hebrews 13:8
Isaiah 66:13
2 Timothy 2:13
"""),
    ("provision", """        # days 261-286 (harvest)
Philippians 4:19
Matthew 6:33
Matthew 6:11
Psalm 34:10
Matthew 7:7-8
James 1:17
Matthew 6:26
Lamentations 3:25
Hebrews 13:5
Psalm 145:15-16
2 Corinthians 9:8
John 6:35
Matthew 6:28-29
Philippians 4:11-12
Zechariah 10:1
Genesis 8:22
Romans 8:32
Psalm 65:11
Luke 6:38
1 Timothy 6:6
Isaiah 55:8-9
John 1:16
Joel 2:26
Proverbs 22:9
2 Corinthians 8:9
Ephesians 3:20-21
"""),
    ("community", """        # days 287-312
Hebrews 10:24-25
Ecclesiastes 4:9-10
Galatians 6:2
Matthew 18:20
Proverbs 27:17
Romans 12:15
1 Thessalonians 5:11
Proverbs 17:17
Acts 2:42
Ephesians 4:29
Psalm 133:1
1 Corinthians 12:26
Colossians 3:16
Proverbs 18:24
Luke 6:31
1 Peter 4:9
Ecclesiastes 4:12
Romans 15:7
Hebrews 13:1-2
1 Timothy 2:1-2
Proverbs 16:24
Galatians 6:10
Matthew 25:40
1 Samuel 12:23
Proverbs 15:1
2 Corinthians 13:11
"""),
    ("gratitude", """        # days 313-338 (Thanksgiving)
1 Thessalonians 5:16-18
Psalm 118:24
Colossians 3:17
Psalm 103:1
Philippians 4:4
1 Chronicles 16:8
Isaiah 25:1
Colossians 2:6-7
Psalm 34:8
2 Corinthians 9:15
Hebrews 13:15
Isaiah 61:10
Psalm 126:3
Colossians 3:15
Deuteronomy 8:10
Psalm 100:4-5
1 Chronicles 16:34
Isaiah 12:5
2 Corinthians 2:14
Psalm 9:1
1 Chronicles 29:13
Isaiah 63:7
Romans 11:36
Revelation 4:11
1 Timothy 1:17
Jude 1:24-25
"""),
    ("peace", """            # days 339-366 (Advent, Christmas = 359/360, blessings to close the year)
Isaiah 40:1
John 14:27
Isaiah 26:3
Isaiah 9:2
Psalm 29:11
Romans 12:18
Isaiah 52:7
Proverbs 14:30
John 1:5
Isaiah 55:12
Romans 15:33
Matthew 5:9
Isaiah 26:12
John 8:12
Psalm 119:165
Isaiah 60:1
James 3:18
Matthew 1:23
Isaiah 9:6
Luke 2:10-11
Luke 2:14
John 1:14
Matthew 2:10
Isaiah 32:17
Romans 14:19
Psalm 85:10
Numbers 6:24-26
2 Thessalonians 3:16
"""),
]

# Fallbacks per theme, tried in order. Non-Psalms first (Psalms sit at the book cap).
ALTERNATES = {
    "purpose": ["Hebrews 11:6", "Psalm 90:17", "Psalm 138:8", "Psalm 16:11"],
    "love": ["1 John 4:11", "Romans 13:10", "Galatians 5:13-14", "Psalm 103:11"],
    "focus": ["Romans 13:14", "Proverbs 21:5", "Psalm 141:3", "Psalm 86:11"],
    "forgiveness": ["Ephesians 2:8-9", "Isaiah 38:17", "Colossians 3:13", "Psalm 32:1", "Psalm 25:7"],
    "hope": ["Romans 15:4", "Romans 8:24-25", "Psalm 39:7", "Psalm 130:5", "Psalm 62:5"],
    "identity": ["1 John 5:4", "Ephesians 1:4", "Romans 14:8", "Psalm 18:19", "Psalm 149:4"],
    "rest": ["Psalm 23:6", "Psalm 116:7", "Psalm 3:5", "Psalm 91:1-2", "Psalm 121:3-4"],
    "courage": ["1 Peter 3:14", "Romans 1:16", "Psalm 31:24", "Psalm 34:4", "Psalm 3:3", "Psalm 27:3"],
    "strength": ["Micah 7:8", "Isaiah 25:4", "Psalm 94:18", "Psalm 119:28", "Psalm 138:3", "Psalm 18:2"],
    "anxiety": ["Philippians 4:5", "Psalm 91:4", "Psalm 91:11", "Psalm 57:1", "Psalm 120:1", "Psalm 145:18"],
    "provision": ["Luke 12:24", "Psalm 84:11", "Psalm 37:3", "Psalm 107:9", "Psalm 16:5-6"],
    "community": ["Proverbs 13:20", "Proverbs 3:27", "Romans 12:4-5", "Hebrews 13:16", "Romans 13:8", "1 John 1:7"],
    "gratitude": ["Psalm 34:1", "Psalm 30:11-12", "Psalm 116:12", "Psalm 40:5", "Psalm 8:1", "Psalm 19:1"],
    "peace": ["Philippians 4:9", "1 Peter 3:11", "Psalm 34:14", "Psalm 37:11"],
}

# God's name: the WEB prints "Yahweh"; the app shows "the LORD". Every rendering was checked by
# eye. Overrides are exact WEB phrases (after quote fixing) for cases the rules below get wrong.
DIVINE_NAME_OVERRIDES = {
    "Psalm 4:8": [(u"for you, Yahweh alone, make", u"for you alone, LORD, make")],
    "Isaiah 40:28": [(u"God, Yahweh, The Creator", u"God, the LORD, The Creator")],
}
VOCATIVE_NEXT = r"(?:you|be|we|I|have|hear|let|remember|show|teach|lead|why|how)\b"


def render_divine_name(ref, text):
    """Return (text, problems). "Yahweh" -> "the LORD" / "The LORD" / "LORD" (vocative)."""
    problems = []
    for old, new in DIVINE_NAME_OVERRIDES.get(ref, []):
        if old not in text:
            problems.append("divine-name override not found: %r" % old)
        text = text.replace(old, new)
    text = re.sub(r"\bLord Yahweh\b", "Lord GOD", text)
    text = re.sub(r"\bO Yahweh\b", "O LORD", text)

    def repl(m):
        before, after = m.string[:m.start()], m.string[m.end():]
        poss = m.group(1) or ""
        sentence_start = before.strip() == "" or re.search(u"(?:[.!?][\u201d\u2019]?\\s+|[\u201c\u2018])$", before)
        vocative = not poss and (
            (re.search(r",\s$", before) and re.match(r"[,.!?]", after))
            or (sentence_start and re.match(r",\s+" + VOCATIVE_NEXT, after)))
        if vocative:
            return "LORD"
        if re.search(r"\bthe\s+$", before, re.I):
            return "LORD" + poss
        return ("The" if sentence_start else "the") + " LORD" + poss

    text = re.sub(u"\\bYahweh(\u2019s)?\\b", repl, text)
    if "Yahweh" in text or re.search(r"\bYah\b", text):
        problems.append("divine name left unrendered")
    if re.search(r"\bthe\s+the\b", text, re.I):
        problems.append("doubled 'the'")
    return text, problems


REF_RE = re.compile(r"^(?P<book>.+?) (?P<ch>\d+):(?P<v1>\d+)(?:-(?P<v2>\d+))?$")
LETTER = re.compile(r"[A-Za-z]")
_last_request = [0.0]


def slug(ref):
    return re.sub(r"[^a-z0-9]+", "_", ref.lower()).strip("_")


def fetch_raw(ref):
    """Return the raw API JSON (str) for ref, from cache or network. None on failure."""
    path = os.path.join(CACHE, slug(ref) + ".json")
    if os.path.exists(path):
        with open(path, encoding="utf-8") as f:
            return f.read()
    url = API.format(urllib.parse.quote(ref.lower(), safe=":"))
    backoff = 15
    for attempt in range(6):
        wait = DELAY - (time.time() - _last_request[0])
        if wait > 0:
            time.sleep(wait)
        _last_request[0] = time.time()
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "daily-verse-content-builder/1.0"})
            with urllib.request.urlopen(req, timeout=30) as r:
                raw = r.read().decode("utf-8")
            json.loads(raw)  # must parse before we cache it
            os.makedirs(CACHE, exist_ok=True)
            with open(path, "w", encoding="utf-8") as f:
                f.write(raw)
            return raw
        except urllib.error.HTTPError as e:
            if e.code == 429:
                print("  429 rate-limited on %s, sleeping %ss" % (ref, backoff), flush=True)
                time.sleep(backoff)
                backoff = min(backoff * 2, 240)
                continue
            if e.code >= 500:
                time.sleep(5 * (attempt + 1))
                continue
            print("  HTTP %s for %s" % (e.code, ref), flush=True)
            return None
        except (urllib.error.URLError, TimeoutError, ValueError) as e:
            print("  error on %s: %s (retrying)" % (ref, e), flush=True)
            time.sleep(5 * (attempt + 1))
    return None


def clean_verse(t):
    t = re.sub(r"\[[^\]]*\]", "", t)                                    # bracketed notes
    t = re.sub(u"[*†‡¹²³⁰-⁹]", "", t)  # footnote marks
    t = re.sub(r"^\s*\d+\s+", "", t)                                    # leading verse number
    return re.sub(r"\s+", " ", t).strip()


def _fix_unmatched(chars, opens, closes, drop):
    """Repair quotes cut off by the verse boundary.

    A close with no opener means the speech began before the span: if it sits at the very
    end the whole text is speech (drop it), otherwise add an opener at the start.
    An opener with no close means the speech runs past the span: if it sits at the very
    start the whole text is speech (drop it), otherwise close it at the end.
    Returns (prepend, append).
    """
    prepend = append = False
    n = len(chars)
    for j, i in enumerate(closes):
        at_end = "".join(chars[i + 1:]).strip() == ""
        if j == 0 and not at_end:
            prepend = True
        else:
            drop.add(i)
    for j, i in enumerate(reversed(opens)):
        at_start = "".join(chars[:i]).strip() == ""
        if j == 0 and not at_start and i < n - 1:
            append = True
        else:
            drop.add(i)
    return prepend, append


def balance_quotes(s):
    """Fix quote marks left open/closed because the span starts or ends mid-speech."""
    chars = list(s)
    drop = set()
    # double quotes “ ”
    stack, stray = [], []
    for i, c in enumerate(chars):
        if c == u"“":
            stack.append(i)
        elif c == u"”":
            if stack:
                stack.pop()
            else:
                stray.append(i)
    d_pre, d_app = _fix_unmatched(chars, stack, stray, drop)
    # single quotes ‘ ’ (’ is also the apostrophe)
    stack, stray = [], []
    for i, c in enumerate(chars):
        if c == u"‘":
            stack.append(i)
        elif c == u"’":
            prev = chars[i - 1] if i > 0 else ""
            nxt = chars[i + 1] if i + 1 < len(chars) else ""
            if prev and nxt and LETTER.match(prev) and LETTER.match(nxt):
                continue                      # apostrophe: don’t
            if prev and prev in u".,!?;:—”":
                if stack:
                    stack.pop()
                else:
                    stray.append(i)           # closing quote with no opener
            elif stack:
                stack.pop()                   # close after a letter: ‘Destroy’
            # else: possessive plural (goodness’ sake), keep
    s_pre, s_app = _fix_unmatched(chars, stack, stray, drop)
    out = "".join(c for i, c in enumerate(chars) if i not in drop)
    out = re.sub(r"\s+", " ", out).strip()
    out = re.sub(r"\s+([,.;:!?])", r"\1", out)
    out = (u"“" if d_pre else "") + (u"‘" if s_pre else "") + out
    out = out + (u"’" if s_app else "") + (u"”" if d_app else "")
    return strip_wrapping(out)


def strip_wrapping(s):
    """A verse that is one quotation from start to end reads better without the outer marks."""
    for o, c in ((u"“", u"”"), (u"‘", u"’")):
        if len(s) > 2 and s[0] == o and s[-1] == c:
            depth = 0
            for i, ch in enumerate(s):
                if ch == o:
                    depth += 1
                elif ch == c and (o == u"“" or (i > 0 and s[i - 1] in u".,!?;:—")):
                    depth -= 1
                    if depth == 0 and i < len(s) - 1:
                        break  # the first quotation closes before the end: keep the marks
            else:
                s = s[1:-1].strip()
    return s


def parse(ref, raw):
    """Return (text, verse_keys, problems)."""
    problems = []
    data = json.loads(raw)
    verses = data.get("verses") or []
    m = REF_RE.match(ref)
    expected = 1
    if m and m.group("v2"):
        expected = int(m.group("v2")) - int(m.group("v1")) + 1
    if len(verses) != expected:
        problems.append("expected %d verses, got %d" % (expected, len(verses)))
    text = " ".join(clean_verse(v.get("text", "")) for v in verses)
    text = balance_quotes(text)
    text, name_problems = render_divine_name(ref, text)
    problems.extend(name_problems)
    keys = [(v.get("book_id"), v.get("chapter"), v.get("verse")) for v in verses]
    if not text:
        problems.append("empty text")
    if len(text) > MAX_LEN:
        problems.append("too long (%d chars)" % len(text))
    first = next((c for c in text if c.isalpha()), "")
    if first and first.islower():
        problems.append("starts mid-sentence (lowercase)")
    if text and text.rstrip(u"”’")[-1:] in (u",", u";", u":", u"—", u"–", u"-"):
        problems.append("ends mid-sentence (%r)" % text.rstrip(u"”’")[-1])
    if re.search(u"[.!?][”’]?\\s+[a-z]", text):
        problems.append("lowercase word after a sentence end")
    if "Selah" in text:
        problems.append("contains Selah")
    if re.search(r"\bYah\b", text):
        problems.append("uses the short form 'Yah'")
    if re.search(r"\d", text):
        problems.append("contains a digit (verse number?)")
    return text, keys, problems


def book_of(ref):
    m = REF_RE.match(ref)
    return m.group("book") if m else ref


def main():
    plan = []
    for theme, block in PLAN:
        lines = [ln.split("#")[0].strip() for ln in block.strip().splitlines()]
        lines = [ln for ln in lines if ln]
        for ln in lines:
            plan.append((theme, ln.split("|")))
    if len(plan) != TOTAL_DAYS:
        sys.exit("PLAN has %d entries, need %d" % (len(plan), TOTAL_DAYS))

    planned_books = {}
    for _, opts in plan:
        b = book_of(opts[0])
        planned_books[b] = planned_books.get(b, 0) + 1

    used_refs, used_keys, used_texts = set(), set(), set()
    book_counts = {}
    entries, substitutions, failed = [], [], []

    def try_ref(ref, theme):
        if ref in used_refs:
            return None, "duplicate ref"
        raw = fetch_raw(ref)
        if raw is None:
            failed.append(ref)
            return None, "fetch failed"
        text, keys, problems = parse(ref, raw)
        if problems:
            return None, "; ".join(problems)
        if any(k in used_keys for k in keys):
            return None, "overlaps a verse already used"
        if text in used_texts:
            return None, "duplicate text"
        b = book_of(ref)
        if book_counts.get(b, 0) + 1 > BOOK_CAP:
            return None, "book cap reached for %s" % b
        return {"ref": ref, "text": text, "theme": theme, "_keys": keys}, None

    for day, (theme, opts) in enumerate(plan, start=1):
        chosen, reasons = None, []
        for ref in opts:
            chosen, why = try_ref(ref, theme)
            if chosen:
                break
            reasons.append("%s: %s" % (ref, why))
        if not chosen:
            for ref in ALTERNATES.get(theme, []):
                if ref in used_refs:
                    continue
                chosen, why = try_ref(ref, theme)
                if chosen:
                    break
                reasons.append("%s: %s" % (ref, why))
        if not chosen:
            sys.exit("Day %d (%s): no usable ref. Tried: %s" % (day, theme, " | ".join(reasons)))
        if chosen["ref"] != opts[0]:
            substitutions.append((day, opts[0], chosen["ref"], reasons[0] if reasons else ""))
        used_refs.add(chosen["ref"])
        used_keys.update(chosen.pop("_keys"))
        used_texts.add(chosen["text"])
        b = book_of(chosen["ref"])
        book_counts[b] = book_counts.get(b, 0) + 1
        entries.append({"day": day, "ref": chosen["ref"], "text": chosen["text"], "theme": theme})
        if day % 25 == 0:
            print("  ...day %d" % day, flush=True)

    # Final validation
    assert len(entries) == TOTAL_DAYS
    assert [e["day"] for e in entries] == list(range(1, TOTAL_DAYS + 1))
    assert len({e["ref"] for e in entries}) == TOTAL_DAYS, "duplicate refs"
    assert all(e["text"].strip() for e in entries), "empty text"
    assert all(len(e["text"]) <= MAX_LEN for e in entries), "text over limit"
    assert all(e["theme"] in THEMES for e in entries), "unknown theme"
    assert max(book_counts.values()) <= BOOK_CAP, "book over cap"

    with open(OUT, "w", encoding="utf-8") as f:
        json.dump(entries, f, ensure_ascii=False, indent=2)
        f.write("\n")

    print("\nWrote %s: %d entries" % (OUT, len(entries)))
    lens = sorted(len(e["text"]) for e in entries)
    print("Length: min %d, median %d, max %d" % (lens[0], lens[len(lens) // 2], lens[-1]))
    print("Themes:", {t: sum(1 for e in entries if e["theme"] == t) for t in THEMES})
    top = sorted(book_counts.items(), key=lambda kv: -kv[1])[:8]
    print("Top books:", ", ".join("%s %d (%.1f%%)" % (b, n, 100.0 * n / TOTAL_DAYS) for b, n in top))
    print("Books used: %d" % len(book_counts))
    if failed:
        print("Failed to fetch: %s" % ", ".join(sorted(set(failed))))
    if substitutions:
        print("Substitutions:")
        for day, old, new, why in substitutions:
            print("  day %d: %s -> %s  (%s)" % (day, old, new, why))
    else:
        print("Substitutions: none")


if __name__ == "__main__":
    main()
