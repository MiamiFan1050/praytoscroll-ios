#!/bin/bash
# Copies the art from ../art into Assets.xcassets as single-scale @3x PNGs, downscaled to the size each one is shown
# at (nothing needs 1024 px at runtime) and palette-compressed with pngquant when it's installed (brew install pngquant;
# about 4x smaller, no visible change). Missing files are skipped: the app falls back to its SwiftUI art for anything
# not in the catalog (MascotView, ArtImage).
set -euo pipefail
cd "$(dirname "$0")/.."
ART=../art
CAT=PrayToScroll/Resources/Assets.xcassets
mkdir -p "$CAT"
cat > "$CAT/Contents.json" <<'J'
{ "info" : { "author" : "xcode", "version" : 1 } }
J
command -v pngquant >/dev/null || echo "note: pngquant not found, importing uncompressed PNGs"

imageset() { # name source [pixels: the @3x size, 3 x the largest point size it's shown at]
  local name=$1 src=$2 px=${3:-600} dir="$CAT/$1.imageset"
  [ -f "$ART/$src" ] || { echo "skip $name ($src missing)"; return; }
  rm -rf "$dir" && mkdir -p "$dir"
  sips -Z "$px" "$ART/$src" --out "$dir/$name.png" >/dev/null
  if command -v pngquant >/dev/null; then
    pngquant --quality=70-95 --speed 1 --strip --force --output "$dir/$name.png" "$dir/$name.png" || true
  fi
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

# The scroll mascot (largest use ~230 pt) and the sealed scroll (gate setup, 150 pt).
imageset Mascot-praying scroll_pray.png 690
imageset Mascot-celebrating scroll_celebrate.png 600
imageset Mascot-waving scroll_wave.png 690
imageset Mascot-sleeping scroll_sleep.png 540
imageset Mascot-phone scroll_phone.png 600
imageset SealScroll seal_scroll.png 450
imageset FlameStreak flame_streak.png 600

# art/v3 (see art/v3/MANIFEST.md). Badges: 150 pt on a badge card, 64 pt in the grid.
for id in firstSave firstGoal streak3 streak7 streak30 read100 read500 read1000 finish10 who10 allThemes firstBoard firstSend; do
  imageset "Badge-$id" "v3/badge_$id.png" 450
done
# Levels: 160 pt on a level-up card, 56 pt on the reading sheet.
n=0
for stage in seed sprout root stem leaf branch bud bloom fruit vine orchard harvest cedar oak mountain; do
  n=$((n + 1)); nn=$(printf "%02d" "$n")
  imageset "Level-$nn" "v3/level_${nn}_$stage.png" 480
done
# Onboarding heroes (up to 240 pt) and empty states (170 pt).
imageset Onboarding-1 v3/onb_1_pray_first.png 720
imageset Onboarding-2 v3/onb_2_pick_apps.png 720
imageset Onboarding-3 v3/onb_3_scroll_word.png 720
imageset Onboarding-4 v3/onb_4_pray_friends.png 720
imageset Empty-saved v3/empty_saved.png 510
imageset Empty-friends v3/empty_friends.png 510
imageset Empty-requests v3/empty_requests.png 510

# App icon: one 1024 px opaque PNG (App Store rejects alpha).
ICON="$CAT/AppIcon.appiconset"
rm -rf "$ICON" && mkdir -p "$ICON"
if [ -f "$ART/icon_1024.png" ] && [ "$(sips -g hasAlpha "$ART/icon_1024.png" | awk '/hasAlpha/ {print $2}')" = "no" ]; then
  cp "$ART/icon_1024.png" "$ICON/icon_1024.png"
  echo "imported AppIcon"
else
  # Fallback: the praying scroll on the midnight background (opaque).
  xcrun swiftc -O tools/make_icon.swift -o "${TMPDIR:-/tmp}/make_icon" && "${TMPDIR:-/tmp}/make_icon" flatten "$ART/scroll_pray.png" "$ICON/icon_1024.png"
  echo "generated AppIcon from scroll_pray.png"
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
