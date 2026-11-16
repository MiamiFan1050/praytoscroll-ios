#!/bin/bash
# Copies the mascot + icon art from ../art into Assets.xcassets (mascots downscaled to 600 px, used as @3x).
# Missing files are skipped; the app falls back to its SwiftUI-drawn art for anything not in the catalog.
set -euo pipefail
cd "$(dirname "$0")/.."
ART=../art
CAT=PrayToScroll/Resources/Assets.xcassets
mkdir -p "$CAT"
cat > "$CAT/Contents.json" <<'J'
{ "info" : { "author" : "xcode", "version" : 1 } }
J

imageset() { # name source
  local name=$1 src=$2 dir="$CAT/$1.imageset"
  [ -f "$ART/$src" ] || { echo "skip $name ($src missing)"; return; }
  rm -rf "$dir" && mkdir -p "$dir"
  sips -Z 600 "$ART/$src" --out "$dir/$name.png" >/dev/null
  cat > "$dir/Contents.json" <<J
{
  "images" : [
    { "idiom" : "universal", "scale" : "1x" },
    { "idiom" : "universal", "scale" : "2x" },
    { "filename" : "$name.png", "idiom" : "universal", "scale" : "3x" }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
J
  echo "imported $name"
}

imageset Mascot-praying scroll_pray.png
imageset Mascot-celebrating scroll_celebrate.png
imageset Mascot-waving scroll_wave.png
imageset Mascot-sleeping scroll_sleep.png
imageset Mascot-phone scroll_phone.png
imageset PadlockGold seal_scroll.png
imageset FlameStreak flame_streak.png

# App icon: one 1024 px opaque PNG (App Store rejects alpha).
ICON="$CAT/AppIcon.appiconset"
rm -rf "$ICON" && mkdir -p "$ICON"
if [ -f "$ART/icon_1024.png" ] && [ "$(sips -g hasAlpha "$ART/icon_1024.png" | awk '/hasAlpha/ {print $2}')" = "no" ]; then
  cp "$ART/icon_1024.png" "$ICON/icon_1024.png"
  echo "imported AppIcon"
else
  # Fallback: the code-drawn key-and-doorway icon.
  xcrun swiftc -O tools/make_icon.swift -o "${TMPDIR:-/tmp}/make_icon" && "${TMPDIR:-/tmp}/make_icon" icon "$ICON/icon_1024.png"
  echo "generated AppIcon in code"
fi
cat > "$ICON/Contents.json" <<'J'
{
  "images" : [
    { "filename" : "icon_1024.png", "idiom" : "universal", "platform" : "ios", "size" : "1024x1024" }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
J

mkdir -p "$CAT/AccentColor.colorset" "$CAT/LaunchBackground.colorset"
cat > "$CAT/AccentColor.colorset/Contents.json" <<'J'
{
  "colors" : [
    { "color" : { "color-space" : "srgb", "components" : { "alpha" : "1.000", "red" : "0.914", "green" : "0.725", "blue" : "0.286" } }, "idiom" : "universal" }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
J
cat > "$CAT/LaunchBackground.colorset/Contents.json" <<'J'
{
  "colors" : [
    { "color" : { "color-space" : "srgb", "components" : { "alpha" : "1.000", "red" : "0.055", "green" : "0.090", "blue" : "0.149" } }, "idiom" : "universal" }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
J
du -sh "$CAT"
