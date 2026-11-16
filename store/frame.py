#!/usr/bin/env python3
"""Pray to Scroll App Store screenshot framer.

Turns raw 1320x2868 simulator screenshots into framed marketing screenshots
(1320x2868, RGB PNG): a serif caption at the top on the midnight-to-ink
gradient, the screenshot in a rounded device frame below, gold accents.

Usage (from anywhere):
    python3 store/frame.py                      # every PNG in store/screenshots/raw/
    python3 store/frame.py --caption "Amen is the *key.*" path/to/shot.png
    python3 store/frame.py --raw DIR --out DIR --captions FILE

Captions come from store/SCREENSHOT_CAPTIONS.md (the markdown table). A raw
named "03-home.png" gets caption 3; files without a number prefix are matched
in sorted order. Words wrapped in *asterisks* render in gold italic. An optional
Badge column puts a small gold pill (e.g. "Free · No ads") above the caption.
Output goes to store/screenshots/framed/ with the same file names. For
fastlane deliver, copy the framed PNGs into its screenshots/en-US/ folder.

Needs Pillow. If the current python3 lacks it, the script re-runs itself with
macOS's /usr/bin/python3 (which ships with Pillow on this Mac), or install it:
python3 -m pip install --user pillow
"""

import argparse
import os
import re
import sys

try:
    from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont
except ImportError:  # pragma: no cover
    alt = "/usr/bin/python3"
    if os.path.exists(alt) and os.path.realpath(sys.executable) != os.path.realpath(alt) \
            and not os.environ.get("PRAYSCROLL_FRAME_REEXEC"):
        os.environ["PRAYSCROLL_FRAME_REEXEC"] = "1"
        os.execv(alt, [alt] + sys.argv)
    sys.exit("Pillow is required: python3 -m pip install --user pillow")

HERE = os.path.dirname(os.path.abspath(__file__))
W, H = 1320, 2868

MIDNIGHT = (14, 23, 38)
INK = (22, 35, 58)
GOLD = (233, 185, 73)
GOLD_WARM = (245, 213, 138)
CREAM = (251, 246, 236)

# Layout (all px on the 1320x2868 canvas)
ORNAMENT_Y = 196
CAPTION_TOP = 262
CAPTION_BOTTOM = 560          # captions are fitted inside this band
CAPTION_MAX_W = 1080
MIN_STRICT_SIZE = 104         # below this, allow a break inside a gold phrase
DEVICE_TOP = 648
DEVICE_BOTTOM_MARGIN = 84
BEZEL = 24
SCREEN_RADIUS = 128

SERIF_CANDIDATES = [
    ("/System/Library/Fonts/NewYork.ttf", "Bold"),
    ("/System/Library/Fonts/Supplemental/Georgia Bold.ttf", None),
    ("/Library/Fonts/Georgia Bold.ttf", None),
]
ROUNDED_CANDIDATES = [
    ("/System/Library/Fonts/SFNSRounded.ttf", "Semibold"),
    ("/System/Library/Fonts/SFNS.ttf", "Semibold"),
    ("/System/Library/Fonts/Supplemental/Arial Bold.ttf", None),
]
SERIF_ITALIC_CANDIDATES = [
    ("/System/Library/Fonts/NewYorkItalic.ttf", "Semibold Italic"),
    ("/System/Library/Fonts/Supplemental/Georgia Bold Italic.ttf", None),
    ("/Library/Fonts/Georgia Bold Italic.ttf", None),
]


# ---------------------------------------------------------------- helpers

def load_font(candidates, size):
    for path, instance in candidates:
        if not os.path.exists(path):
            continue
        try:
            font = ImageFont.truetype(path, size)
            if instance:
                try:
                    font.set_variation_by_name(instance)
                except Exception:
                    pass
            return font
        except OSError:
            continue
    return ImageFont.load_default(size)


def vertical_gradient(size, top, bottom):
    w, h = size
    mask = Image.linear_gradient("L").resize((w, h))
    return Image.composite(Image.new("RGB", size, bottom), Image.new("RGB", size, top), mask)


def radial_glow(size, color, strength):
    """A soft radial blob: full colour in the middle, fading to nothing."""
    # Pillow's radial gradient reaches only ~180 at the circle's edge; stretch it so
    # the glow is fully transparent at the rim (no visible square).
    dist = Image.radial_gradient("L").point(lambda v: min(255, int(v * 255 / 180)))
    alpha = ImageChops.invert(dist).resize(size, Image.BICUBIC)
    alpha = alpha.point(lambda v: int((v / 255.0) ** 2.2 * 255 * strength))
    layer = Image.new("RGBA", size, color + (0,))
    layer.putalpha(alpha)
    return layer


def rounded_mask(size, radius, ss=4):
    """Anti-aliased rounded-rectangle mask (supersampled)."""
    w, h = size
    big = Image.new("L", (w * ss, h * ss), 0)
    ImageDraw.Draw(big).rounded_rectangle((0, 0, w * ss - 1, h * ss - 1), radius * ss, fill=255)
    return big.resize(size, Image.LANCZOS)


def paste_shape(canvas, box, radius, fill, ss=4):
    """Composite an anti-aliased rounded rect filled with a colour or an image."""
    x0, y0, x1, y1 = [int(round(v)) for v in box]
    size = (x1 - x0, y1 - y0)
    mask = rounded_mask(size, radius, ss)
    src = fill if isinstance(fill, Image.Image) else Image.new("RGB", size, fill)
    canvas.paste(src.convert("RGB"), (x0, y0), mask)


def add_grain(img, sigma=5, amount=1.0):
    """Very light film grain: kills gradient banding, reads as 'print', not 'noise'."""
    noise = Image.effect_noise(img.size, sigma).convert("RGB")
    grained = ImageChops.add(img, noise, scale=1.0, offset=-128)
    return Image.blend(img, grained, amount)


# ---------------------------------------------------------------- caption

def parse_runs(caption):
    """'Pray first. *Scroll after.*' -> [('Pray', False), ('first.', False), ('Scroll', True), ('after.', True)]"""
    words = []
    for i, part in enumerate(re.split(r"\*", caption)):
        for word in part.split():
            words.append((word, i % 2 == 1))
    return words


def layouts(words, max_lines):
    n = len(words)
    if n == 0:
        return
    # every way to split n words into k consecutive lines
    def splits(start, k):
        if k == 1:
            yield [words[start:]]
            return
        for cut in range(start + 1, n - k + 2):
            for rest in splits(cut, k - 1):
                yield [words[start:cut]] + rest
    for k in range(1, min(max_lines, n) + 1):
        for lines in splits(0, k):
            yield lines


def line_width(line, reg, ita):
    space = reg.getlength(" ")
    return sum((ita if emph else reg).getlength(w) for w, emph in line) + space * (len(line) - 1)


def splits_emphasis(lines):
    """True if a line break falls inside a gold phrase (e.g. 'prayer / streak')."""
    return any(lines[i][-1][1] and lines[i + 1][0][1] for i in range(len(lines) - 1))


def fit_caption(caption, size=None):
    """Pick the largest size + most balanced line breaks that fit the caption band.

    With `size`, use exactly that size (so a batch can share one type size).
    A layout that keeps every gold phrase on one line is preferred down to
    MIN_STRICT_SIZE before a split is allowed.
    """
    words = parse_runs(caption)
    sizes = [size] if size else range(150, 70, -2)
    for strict in (True, False):
        for sz in sizes:
            if strict and not size and sz < MIN_STRICT_SIZE:
                break
            got = _fit_at(words, sz, strict)
            if got:
                return got
    raise SystemExit(f"Caption too long to fit: {caption!r}")


def _fit_at(words, size, strict):
    band_h = CAPTION_BOTTOM - CAPTION_TOP
    if True:
        reg = load_font(SERIF_CANDIDATES, size)
        ita = load_font(SERIF_ITALIC_CANDIDATES, size)
        lh = int(size * 1.13)
        best = None
        for lines in layouts(words, 3):
            if strict and splits_emphasis(lines):
                continue
            if len(lines) * lh - (lh - size) > band_h + size * 0.15:
                continue
            widths = [line_width(l, reg, ita) for l in lines]
            if max(widths) > CAPTION_MAX_W:
                continue
            # fewest lines first; then balance, with a nudge to break where the
            # gold emphasis starts or ends so each colour reads as one phrase
            boundary = sum(1 for i in range(len(lines) - 1) if lines[i][-1][1] != lines[i + 1][0][1])
            score = (len(lines), max(widths) - min(widths) - 260 * boundary)
            if best is None or score < best[0]:
                best = (score, lines, widths)
        if best:
            return size, reg, ita, lh, best[1], best[2]
    return None


def draw_caption(canvas, caption, size=None):
    size, reg, ita, lh, lines, widths = fit_caption(caption, size)
    block_h = len(lines) * lh - (lh - size)
    y = CAPTION_TOP + ((CAPTION_BOTTOM - CAPTION_TOP) - block_h) // 2
    space = reg.getlength(" ")

    glow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    gdraw = ImageDraw.Draw(glow)
    for line, width in zip(lines, widths):
        x = (W - width) / 2
        for word, emph in line:
            font = ita if emph else reg
            if emph:
                gdraw.text((x, y), word, font=font, fill=GOLD + (140,))
            x += font.getlength(word) + space
        y += lh
    # soft halo under gold words
    halo = glow.filter(ImageFilter.GaussianBlur(28))
    halo.putalpha(halo.getchannel("A").point(lambda v: int(v * 0.45)))
    base = canvas.convert("RGBA")
    base = Image.alpha_composite(base, halo)
    # redraw the text crisp on top of the halo
    d2 = ImageDraw.Draw(base)
    y = CAPTION_TOP + ((CAPTION_BOTTOM - CAPTION_TOP) - block_h) // 2
    for line, width in zip(lines, widths):
        x = (W - width) / 2
        for word, emph in line:
            font = ita if emph else reg
            d2.text((x, y), word, font=font, fill=GOLD if emph else CREAM)
            x += font.getlength(word) + space
        y += lh
    return base.convert("RGB")


def draw_badge(canvas, text):
    """A gold-outlined pill in place of the ornament, e.g. 'Free · No ads · No account'."""
    ss = 3
    size = 34
    font = load_font(ROUNDED_CANDIDATES, size * ss)
    tracking = 0.09 * size * ss
    label = text.upper()
    widths = [font.getlength(ch) for ch in label]
    text_w = sum(widths) + tracking * (len(label) - 1)
    pad_x, h = 46 * ss, 84 * ss
    w = int(text_w + 2 * pad_x)
    big = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(big)
    d.rounded_rectangle((0, 0, w - 1, h - 1), h // 2, fill=(14, 23, 38, 150), outline=GOLD + (210,), width=2 * ss)
    x = pad_x
    asc, desc = font.getmetrics()
    y = (h - (asc + desc)) // 2 + 2 * ss
    for ch, cw in zip(label, widths):
        d.text((x, y), ch, font=font, fill=GOLD if ch == "\u00b7" else CREAM)
        x += cw + tracking
    small = big.resize((w // ss, h // ss), Image.LANCZOS)
    base = canvas.convert("RGBA")
    base.alpha_composite(radial_glow((900, 260), GOLD, 0.16), ((W - 900) // 2, ORNAMENT_Y - 130))
    base.alpha_composite(small, ((W - small.width) // 2, ORNAMENT_Y - small.height // 2 - 8))
    return base.convert("RGB")


def draw_ornament(canvas):
    """Two gold hairlines with a small four-point star between them."""
    ss = 4
    w, h = 360, 40
    big = Image.new("RGBA", (w * ss, h * ss), (0, 0, 0, 0))
    d = ImageDraw.Draw(big)
    cx, cy = w * ss // 2, h * ss // 2
    line_alpha = 170
    for sign in (-1, 1):
        x_near = cx + sign * 34 * ss
        x_far = cx + sign * 150 * ss
        # fade the hairline outwards
        steps = 40
        for i in range(steps):
            a = int(line_alpha * (1 - i / steps))
            xa = x_near + (x_far - x_near) * i / steps
            xb = x_near + (x_far - x_near) * (i + 1) / steps
            d.line([(xa, cy), (xb, cy)], fill=GOLD + (a,), width=2 * ss)
    r_long, r_short = 17 * ss, 4.2 * ss
    star = [(cx, cy - r_long), (cx + r_short, cy - r_short), (cx + r_long, cy), (cx + r_short, cy + r_short),
            (cx, cy + r_long), (cx - r_short, cy + r_short), (cx - r_long, cy), (cx - r_short, cy - r_short)]
    d.polygon(star, fill=GOLD_WARM + (255,))
    small = big.resize((w, h), Image.LANCZOS)
    base = canvas.convert("RGBA")
    # glow behind the star
    glow = radial_glow((160, 160), GOLD, 0.55)
    base.alpha_composite(glow, ((W - 160) // 2, ORNAMENT_Y - 80))
    base.alpha_composite(small, ((W - w) // 2, ORNAMENT_Y - h // 2))
    return base.convert("RGB")


# ---------------------------------------------------------------- device

def device_geometry():
    screen_h = H - DEVICE_TOP - DEVICE_BOTTOM_MARGIN - 2 * BEZEL
    screen_w = round(screen_h * 1320 / 2868)
    dev_w, dev_h = screen_w + 2 * BEZEL, screen_h + 2 * BEZEL
    x0 = (W - dev_w) // 2
    return {
        "device": (x0, DEVICE_TOP, x0 + dev_w, DEVICE_TOP + dev_h),
        "screen": (x0 + BEZEL, DEVICE_TOP + BEZEL, x0 + BEZEL + screen_w, DEVICE_TOP + BEZEL + screen_h),
        "screen_size": (screen_w, screen_h),
    }


def draw_device(canvas, shot):
    g = device_geometry()
    dx0, dy0, dx1, dy1 = g["device"]
    sx0, sy0, sx1, sy1 = g["screen"]
    sw, sh = g["screen_size"]
    dev_w, dev_h = dx1 - dx0, dy1 - dy0
    outer_r = SCREEN_RADIUS + BEZEL

    base = canvas.convert("RGBA")

    # 1) gold aura + drop shadow
    pad = 260
    m = Image.new("L", (dev_w + 2 * pad, dev_h + 2 * pad), 0)
    m.paste(rounded_mask((dev_w, dev_h), outer_r, ss=2), (pad, pad))
    aura = Image.new("RGBA", m.size, GOLD + (0,))
    aura.putalpha(m.filter(ImageFilter.GaussianBlur(120)).point(lambda v: int(v * 0.10)))
    base.alpha_composite(aura, (dx0 - pad, dy0 - pad - 40))
    shadow = Image.new("RGBA", m.size, (0, 0, 0, 0))
    shadow.putalpha(m.filter(ImageFilter.GaussianBlur(46)).point(lambda v: int(v * 0.70)))
    base.alpha_composite(shadow, (dx0 - pad, dy0 - pad + 34))
    canvas = base.convert("RGB")

    # 2) side buttons (titanium), drawn before the body so they tuck under it
    btn = (58, 70, 92)
    for (y, h) in ((0.165, 0.043), (0.235, 0.075), (0.325, 0.075)):      # action, volume up, volume down
        paste_shape(canvas, (dx0 - 6, dy0 + dev_h * y, dx0 + 10, dy0 + dev_h * (y + h)), 5, btn)
    for (y, h) in ((0.255, 0.11), (0.60, 0.062)):                          # side button, camera control
        paste_shape(canvas, (dx1 - 10, dy0 + dev_h * y, dx1 + 6, dy0 + dev_h * (y + h)), 5, btn)

    # 3) body: a thin warm-gold rim, a titanium band, then the black bezel
    rim = vertical_gradient((dev_w, dev_h), (196, 160, 92), (120, 98, 60))
    paste_shape(canvas, g["device"], outer_r, rim)
    band = vertical_gradient((dev_w - 4, dev_h - 4), (64, 76, 100), (30, 38, 56))
    paste_shape(canvas, (dx0 + 2, dy0 + 2, dx1 - 2, dy1 - 2), outer_r - 2, band)
    paste_shape(canvas, (dx0 + 9, dy0 + 9, dx1 - 9, dy1 - 9), outer_r - 9, (6, 8, 12))

    # 4) the screenshot
    shot = shot.convert("RGB")
    if shot.size != (sw, sh):
        shot = shot.resize((sw, sh), Image.LANCZOS)
    paste_shape(canvas, g["screen"], SCREEN_RADIUS, shot)

    # 5) Dynamic Island (simulator captures leave it out)
    iw, ih = round(sw * 0.287), round(sh * 0.0385)
    ix0 = sx0 + (sw - iw) // 2
    iy0 = sy0 + round(sh * 0.0118)
    paste_shape(canvas, (ix0, iy0, ix0 + iw, iy0 + ih), ih // 2, (0, 0, 0))

    # 6) a faint top-edge highlight on the rim
    hl = Image.new("RGBA", (dev_w, dev_h), (0, 0, 0, 0))
    ImageDraw.Draw(hl).rounded_rectangle((1, 1, dev_w - 2, dev_h - 2), outer_r, outline=GOLD_WARM + (90,), width=2)
    fade = Image.linear_gradient("L").resize((dev_w, dev_h)).point(lambda v: 255 - v)
    hl.putalpha(ImageChops.multiply(hl.getchannel("A"), fade))
    base = canvas.convert("RGBA")
    base.alpha_composite(hl, (dx0, dy0))
    return base.convert("RGB")


# ---------------------------------------------------------------- compose

def background():
    bg = vertical_gradient((W, H), MIDNIGHT, INK)
    base = bg.convert("RGBA")
    # a luminous blue lift behind the caption, a whisper of gold at its heart
    base.alpha_composite(radial_glow((2000, 1500), (38, 58, 96), 0.85), ((W - 2000) // 2, -560))
    base.alpha_composite(radial_glow((1100, 760), GOLD, 0.10), ((W - 1100) // 2, 40))
    base.alpha_composite(radial_glow((1800, 1600), (30, 46, 78), 0.6), ((W - 1800) // 2, 1500))
    return base.convert("RGB")


def frame(shot_path, caption, out_path, size=None, badge=None):
    shot = Image.open(shot_path)
    img = background()
    img = add_grain(img, sigma=2.4, amount=1.0)
    img = draw_badge(img, badge) if badge else draw_ornament(img)
    img = draw_caption(img, caption, size)
    img = draw_device(img, shot)
    img = img.convert("RGB")
    img.save(out_path, "PNG", optimize=True)
    return out_path


def read_captions(path):
    caps = {}
    with open(path, encoding="utf-8") as f:
        for line in f:
            m = re.match(r"^\|\s*(\d+)\s*\|\s*(.+?)\s*\|", line)
            if m:
                cells = [c.strip() for c in line.strip().strip("|").split("|")]
                badge = cells[2] if len(cells) > 3 and cells[2] not in ("", "-", "—") else None
                caps[int(m.group(1))] = (m.group(2), badge)
    if not caps:
        raise SystemExit(f"No captions found in {path}")
    return caps


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("files", nargs="*", help="specific raw PNGs (default: every PNG in --raw)")
    ap.add_argument("--raw", default=os.path.join(HERE, "screenshots", "raw"))
    ap.add_argument("--out", default=os.path.join(HERE, "screenshots", "framed"))
    ap.add_argument("--captions", default=os.path.join(HERE, "SCREENSHOT_CAPTIONS.md"))
    ap.add_argument("--caption", help="use this caption for every file given")
    ap.add_argument("--badge", help="with --caption: a small pill above it instead of the ornament")
    args = ap.parse_args()

    files = args.files or sorted(
        os.path.join(args.raw, f) for f in os.listdir(args.raw)
        if f.lower().endswith((".png", ".jpg", ".jpeg")) and not f.startswith(".")
    )
    if not files:
        raise SystemExit(f"No screenshots in {args.raw}")
    caps = None if args.caption else read_captions(args.captions)
    os.makedirs(args.out, exist_ok=True)

    jobs = []
    for i, path in enumerate(files, start=1):
        name = os.path.basename(path)
        if args.caption:
            caption, badge = args.caption, args.badge
        else:
            m = re.match(r"^(\d+)", name)
            idx = int(m.group(1)) if m else i
            if idx not in caps:
                print(f"skip {name}: no caption #{idx}")
                continue
            caption, badge = caps[idx]
        jobs.append((path, name, caption, badge))

    # One type size for the whole set: the largest size every caption fits at.
    fitted = {c: fit_caption(c) for _, _, c, _ in jobs}
    shared = min(f[0] for f in fitted.values())

    for path, name, caption, badge in jobs:
        own = fitted[caption]
        size = min(shared, own[0])
        if size != own[0] and not _fit_at(parse_runs(caption), size, True):
            size = own[0]
        out = os.path.join(args.out, os.path.splitext(name)[0] + ".png")
        frame(path, caption, out, size, badge)
        print(f"framed {name} -> {out}  [{caption}] {size}px")


if __name__ == "__main__":
    main()
