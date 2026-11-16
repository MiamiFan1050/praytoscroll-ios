#!/usr/bin/env python3
"""Validate every content file against the app's schemas and counts.

Usage:  python3 tools/validate_content.py      (exit 0 = all good, 1 = errors)

Checks verses.json (and re-derives every verse text from the cached bible-api responses,
so nothing in the file can be hand-typed), prompts.json, challenges.json and copy.json.
SF Symbol names are checked against macOS's CoreGlyphs list (release year <= 2023,
i.e. available in SF Symbols 5 / iOS 17).
"""
import json
import os
import plistlib
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)
import fetch_verses as fv  # noqa: E402

errors, warnings = [], []


def err(msg):
    errors.append(msg)


def warn(msg):
    warnings.append(msg)


def load(name):
    path = os.path.join(ROOT, name)
    try:
        with open(path, encoding="utf-8") as f:
            return json.load(f)
    except Exception as e:  # noqa: BLE001
        err("%s: cannot load (%s)" % (name, e))
        return None


def is_str(x):
    return isinstance(x, str) and x.strip() != ""


def placeholders(s):
    return set(re.findall(r"\{[A-Za-z]+\}", s))


def walk_strings(obj):
    if isinstance(obj, str):
        yield obj
    elif isinstance(obj, list):
        for x in obj:
            yield from walk_strings(x)
    elif isinstance(obj, dict):
        for v in obj.values():
            yield from walk_strings(v)


# ---------------------------------------------------------------- verses.json
def check_verses():
    data = load("verses.json")
    if data is None:
        return {}
    if not isinstance(data, list) or len(data) != 366:
        err("verses.json: expected a list of 366 entries, got %s" % (len(data) if isinstance(data, list) else type(data)))
        return {}
    days, refs, texts, books, themes = [], set(), set(), {}, {}
    for e in data:
        if not isinstance(e, dict) or set(e.keys()) != {"day", "ref", "text", "theme"}:
            err("verses.json: bad keys in %r" % (e,))
            continue
        d, ref, text, theme = e["day"], e["ref"], e["text"], e["theme"]
        if not isinstance(d, int):
            err("verses.json: day not int: %r" % d)
        days.append(d)
        if not is_str(ref) or not fv.REF_RE.match(ref):
            err("verses.json day %s: bad ref %r" % (d, ref))
        if ref in refs:
            err("verses.json: duplicate ref %s" % ref)
        refs.add(ref)
        if not is_str(text):
            err("verses.json day %s: empty text" % d)
            continue
        if text in texts:
            err("verses.json day %s: duplicate text" % d)
        texts.add(text)
        if len(text) > fv.MAX_LEN:
            err("verses.json day %s: %d chars > %d" % (d, len(text), fv.MAX_LEN))
        if re.search(r"\d", text) or "Selah" in text or text != text.strip() or "  " in text:
            err("verses.json day %s: unnormalized text" % d)
        if theme not in fv.THEMES:
            err("verses.json day %s: unknown theme %r" % (d, theme))
        themes[theme] = themes.get(theme, 0) + 1
        b = fv.book_of(ref)
        books[b] = books.get(b, 0) + 1
        # provenance: text must equal what the cached API response produces
        cache = os.path.join(fv.CACHE, fv.slug(ref) + ".json")
        if not os.path.exists(cache):
            err("verses.json day %s: no cached API response for %s" % (d, ref))
        else:
            with open(cache, encoding="utf-8") as f:
                raw = f.read()
            derived, _, problems = fv.parse(ref, raw)
            if derived != text:
                err("verses.json day %s: text differs from the bible-api response for %s" % (d, ref))
            if problems:
                err("verses.json day %s: %s" % (d, "; ".join(problems)))
            if json.loads(raw).get("translation_id") != fv.TRANSLATION:
                err("verses.json day %s: cached response is not %s" % (d, fv.TRANSLATION))
            if "Yahweh" in text:
                err("verses.json day %s: says Yahweh (expected the LORD)" % d)
    if sorted(days) != list(range(1, 367)):
        err("verses.json: days are not exactly 1..366")
    cap = int(366 * 0.15)
    for b, n in books.items():
        if n > cap:
            err("verses.json: %s has %d entries (> %d, 15%%)" % (b, n, cap))
    for t in fv.THEMES:
        if themes.get(t, 0) < 20:
            err("verses.json: theme %s has only %d entries" % (t, themes.get(t, 0)))
    return {"entries": len(data), "themes": themes, "books": books}


# ---------------------------------------------------------------- prompts.json
PROMPT_KEYS = ["adoration", "confession", "thanksgiving", "supplication", "quick", "forSomeone"]
PROMPT_MIN = {"quick": 120}
PREACHY = re.compile(r"\b(should|must|ought|shame on|lazy|addict\w*|wasted?|sinful|repent)\b", re.I)


def sentence_count(s):
    stripped = re.sub(u"“[^”]*”", "Q", s)  # quoted speech counts as one word
    return len(re.findall(r"[.!?](\s|$)", stripped))


def check_prompts():
    data = load("prompts.json")
    if data is None:
        return {}
    if not isinstance(data, dict) or set(data.keys()) != set(PROMPT_KEYS):
        err("prompts.json: keys must be exactly %s, got %s" % (PROMPT_KEYS, list(data.keys()) if isinstance(data, dict) else type(data)))
        return {}
    seen = {}
    counts = {}
    for key in PROMPT_KEYS:
        items = data[key]
        need = PROMPT_MIN.get(key, 40)
        if not isinstance(items, list) or len(items) < need:
            err("prompts.json %s: need >= %d, got %s" % (key, need, len(items) if isinstance(items, list) else type(items)))
            continue
        counts[key] = len(items)
        for p in items:
            if not is_str(p):
                err("prompts.json %s: empty or non-string prompt" % key)
                continue
            norm = p.lower().strip()
            if norm in seen:
                err("prompts.json: duplicate prompt in %s and %s: %r" % (seen[norm], key, p))
            seen[norm] = key
            ph = placeholders(p)
            if ph - {"{name}"}:
                err("prompts.json %s: unknown placeholder in %r" % (key, p))
            if "{name}" in ph and key not in ("supplication", "forSomeone"):
                err("prompts.json %s: {name} only allowed in supplication/forSomeone: %r" % (key, p))
            if key == "forSomeone" and "{name}" not in ph:
                err("prompts.json forSomeone: missing {name}: %r" % p)
            if sentence_count(p) > 2:
                err("prompts.json %s: more than 2 sentences: %r" % (key, p))
            if len(p) > 130:
                err("prompts.json %s: too long (%d chars): %r" % (key, len(p), p))
            if "'" in p or '"' in p:
                warn("prompts.json %s: straight quote/apostrophe in %r" % (key, p))
            if PREACHY.search(p):
                warn("prompts.json %s: check tone (%s): %r" % (key, PREACHY.search(p).group(0), p))
    return counts


# ---------------------------------------------------------------- challenges.json
CHALLENGE_KEYS = {"id", "title", "days", "subtitle", "description", "dailyTips", "badgeSymbol"}
REQUIRED_CHALLENGES = {"Fresh Start": 7, "21-Day Habit": 21, "40-Day Social Media Fast": 40,
                       "Pray for 30 People": 30, "Gratitude Week": 7, "Psalms Mornings": 14}
GLYPHS = "/System/Library/CoreServices/CoreGlyphs.bundle/Contents/Resources/name_availability.plist"


def symbol_years():
    try:
        with open(GLYPHS, "rb") as f:
            return plistlib.load(f)["symbols"]
    except Exception as e:  # noqa: BLE001
        warn("SF Symbols list unavailable (%s); badge names not verified" % e)
        return None


def check_challenges():
    data = load("challenges.json")
    if data is None:
        return {}
    if not isinstance(data, list) or len(data) < 6:
        err("challenges.json: need a list of >= 6 challenges")
        return {}
    syms = symbol_years()
    ids, titles = set(), {}
    for c in data:
        if not isinstance(c, dict) or set(c.keys()) != CHALLENGE_KEYS:
            err("challenges.json: bad keys %s" % (sorted(c.keys()) if isinstance(c, dict) else c))
            continue
        cid = c["id"]
        if not isinstance(cid, str) or not re.match(r"^[a-z][a-z0-9]*(-[a-z0-9]+)*$", cid):
            err("challenges.json: id not kebab-case: %r" % cid)
        if cid in ids:
            err("challenges.json: duplicate id %s" % cid)
        ids.add(cid)
        for k in ("title", "subtitle", "description", "badgeSymbol"):
            if not is_str(c[k]):
                err("challenges.json %s: empty %s" % (cid, k))
        if not isinstance(c["days"], int) or c["days"] < 1:
            err("challenges.json %s: bad days" % cid)
            continue
        if len(c["description"]) > 240:
            err("challenges.json %s: description %d chars > 240" % (cid, len(c["description"])))
        tips = c["dailyTips"]
        if not isinstance(tips, list) or len(tips) != c["days"]:
            err("challenges.json %s: %s tips for %d days" % (cid, len(tips) if isinstance(tips, list) else "?", c["days"]))
        elif not all(is_str(t) for t in tips) or len(set(tips)) != len(tips):
            err("challenges.json %s: empty or duplicate tips" % cid)
        elif max(len(t) for t in tips) > 120:
            err("challenges.json %s: a tip is over 120 chars" % cid)
        if syms is not None:
            year = syms.get(c["badgeSymbol"])
            if year is None:
                err("challenges.json %s: SF Symbol %r does not exist" % (cid, c["badgeSymbol"]))
            elif float(year) >= 2024:
                err("challenges.json %s: SF Symbol %r is newer than SF Symbols 5 (%s)" % (cid, c["badgeSymbol"], year))
        titles[c["title"]] = c["days"]
    for t, d in REQUIRED_CHALLENGES.items():
        if titles.get(t) != d:
            err("challenges.json: missing required challenge %s (%d days)" % (t, d))
    return {c["id"]: c["days"] for c in data if isinstance(c, dict) and "id" in c}


# ---------------------------------------------------------------- copy.json
ONBOARDING = ["welcome", "scrollQuiz", "mirror", "promise", "chooseApps", "unlockStyle", "window",
              "reminders", "name", "gateSetup", "firstPrayer"]
NOTIF = {"dailyReminder": 5, "streakAtRisk": 4, "morningVerse": 3}
EMPTY = ["people", "journal", "circles", "answeredPrayers"]
APP_NAME = "Pray to Scroll"
OLD_NAMES = ["PrayPass", "AmenKey", "Amen is the key"]


def check_copy():
    data = load("copy.json")
    if data is None:
        return {}
    ob = data.get("onboarding", {})
    for k in ONBOARDING:
        s = ob.get(k)
        if not isinstance(s, dict) or not is_str(s.get("headline")) or not is_str(s.get("subline")):
            err("copy.json onboarding.%s: needs headline + subline" % k)
    nt = data.get("notifications", {})
    for k, n in NOTIF.items():
        items = nt.get(k)
        if not isinstance(items, list) or len(items) != n:
            err("copy.json notifications.%s: need exactly %d" % (k, n))
            continue
        for m in items:
            if not isinstance(m, dict) or not is_str(m.get("title")) or not is_str(m.get("body")):
                err("copy.json notifications.%s: each needs title + body" % k)
    if not all("{streak}" in (m.get("title", "") + m.get("body", "")) for m in nt.get("streakAtRisk", [])):
        err("copy.json: every streakAtRisk message should show {streak}")
    if not all("{verseText}" in m.get("body", "") for m in nt.get("morningVerse", [])):
        err("copy.json: every morningVerse body should include {verseText}")
    cel = data.get("celebrations")
    if not isinstance(cel, list) or len(cel) != 12 or not all(is_str(c) for c in cel) or len(set(cel)) != 12:
        err("copy.json celebrations: need 12 unique lines")
    es = data.get("emptyStates", {})
    for k in EMPTY:
        s = es.get(k)
        if not isinstance(s, dict) or not is_str(s.get("title")) or not is_str(s.get("message")):
            err("copy.json emptyStates.%s: needs title + message" % k)
    documented = set((data.get("placeholders") or {}).keys())
    used = set()
    for key in ("onboarding", "notifications", "celebrations", "emptyStates"):
        for s in walk_strings(data.get(key)):
            used |= placeholders(s)
    if used - documented:
        err("copy.json: undocumented placeholders %s" % sorted(used - documented))
    if documented - used - {"{name}"}:
        warn("copy.json: documented but unused placeholders %s" % sorted(documented - used))
    if data.get("appName") != APP_NAME:
        err("copy.json: appName must be %s" % APP_NAME)
    if not any(APP_NAME in x for x in walk_strings(data.get("onboarding"))):
        err("copy.json: onboarding never names the app")
    return {"celebrations": len(cel or []), "notifications": {k: len(nt.get(k, [])) for k in NOTIF}}


def check_global():
    for name in ("prompts.json", "challenges.json", "copy.json"):
        with open(os.path.join(ROOT, name), encoding="utf-8") as f:
            raw = f.read()
        for old in OLD_NAMES:
            if old.lower() in raw.lower():
                err("%s: still names an old app name (%s); the app is %s" % (name, old, APP_NAME))
        data = json.loads(raw)
        skip_docs = data.get("placeholders") if isinstance(data, dict) else None
        for s in walk_strings(data):
            if skip_docs and s in skip_docs.values():
                continue
            if "  " in s or s != s.strip():
                err("%s: stray whitespace in %r" % (name, s))
            if "'" in s:
                warn("%s: straight apostrophe in %r" % (name, s))


# British spellings. Verse text is the WEBBE as published (never edited); the app copy is US English.
BRITISH = re.compile(
    r"\b(?:dis)?(?:honour|favour|neighbour|saviour|labour|behaviour|splendour|colour|odour|armour|"
    r"harbour|vigour|valour|rumour|clamour|fervour|endeavour|savour|ardour|humour|rigour|succour|"
    r"candour|parlour)\w*|\b(?:towards|amongst|whilst|grey|centre|centres|sceptre|theatre|judgement|"
    r"judgements|defence|offence|offences|pretence|licence|fulfil|fulfils|fulfilment|enrol|wilful|"
    r"skilful|cheque|plough\w*|mould\w*|counsell\w*|travell\w*|marvell\w*|jewell\w*|worshipp\w*|"
    r"quarrell\w*|practis\w*|realis\w*|recognis\w*|organis\w*|apologis\w*|baptis\w*|"
    r"sympathis\w*|idolis\w*|scandalis\w*|tranquill\w*|learnt|spelt|dreamt|spoilt)\b",
    re.I)


def british_report():
    counts = {}
    try:
        with open(os.path.join(ROOT, "verses.json"), encoding="utf-8") as f:
            entries = json.load(f)
    except Exception:  # noqa: BLE001
        return counts, []
    examples = []
    for e in entries:
        for m in BRITISH.finditer(e.get("text", "")):
            w = m.group(0).lower()
            counts[w] = counts.get(w, 0) + 1
            if len(examples) < 10 and all(w != x[0] for x in examples):
                examples.append((w, e["ref"]))
    for name in ("prompts.json", "challenges.json", "copy.json"):
        with open(os.path.join(ROOT, name), encoding="utf-8") as f:
            data = json.load(f)
        for s_ in walk_strings(data):
            for m in BRITISH.finditer(s_):
                err("%s: British spelling %r (app copy is US English)" % (name, m.group(0)))
    return counts, examples


def main():
    v = check_verses()
    p = check_prompts()
    c = check_challenges()
    k = check_copy()
    check_global()
    print("verses.json:     %s entries; themes %s" % (v.get("entries"), v.get("themes")))
    if v.get("books"):
        top = sorted(v["books"].items(), key=lambda kv: -kv[1])[:5]
        print("                 top books %s (cap %d)" % (", ".join("%s %d" % t for t in top), int(366 * 0.15)))
    print("prompts.json:    %s (total %d)" % (p, sum(p.values()) if p else 0))
    print("challenges.json: %s" % c)
    print("copy.json:       %s" % k)
    bc, bex = british_report()
    print("British spellings in verses.json (WEBBE, kept verbatim): %d occurrences in %d forms"
          % (sum(bc.values()), len(bc)))
    if bc:
        print("                 " + ", ".join("%s %d" % kv for kv in sorted(bc.items(), key=lambda kv: -kv[1])))
    for w in warnings:
        print("WARN  " + w)
    for e in errors:
        print("ERROR " + e)
    print("\n%s: %d errors, %d warnings" % ("FAIL" if errors else "PASS", len(errors), len(warnings)))
    sys.exit(1 if errors else 0)


if __name__ == "__main__":
    main()
