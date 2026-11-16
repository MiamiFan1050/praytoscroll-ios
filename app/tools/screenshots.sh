#!/bin/bash
# Local App Store screenshots (needs Xcode): generates the project, boots the best 6.9" simulator,
# sets a 9:41 status bar and runs the PrayToScrollScreenshots scheme. PNGs land in ../store/screenshots/raw/
# (1320×2868 on an iPhone 16/17 Pro Max) and as "NN-name" attachments in build/ui.xcresult.
# The machine is shared: waits for any other xcodebuild to finish first.
set -euo pipefail
cd "$(dirname "$0")/.."
while pgrep -x xcodebuild >/dev/null; do echo "another xcodebuild is running; waiting 30s"; sleep 30; done
OUT="$(cd .. && pwd)/store/screenshots/raw"
mkdir -p "$OUT" build
xcodegen generate >/dev/null
SIM=$(bash ../ci/pick_sim.sh)
xcrun simctl boot "$SIM" 2>/dev/null || true
xcrun simctl bootstatus "$SIM" -b >/dev/null
xcrun simctl status_bar "$SIM" override --time "9:41" --dataNetwork wifi --wifiMode active --wifiBars 3 \
  --cellularMode active --cellularBars 4 --batteryState charged --batteryLevel 100 || true
rm -rf build/ui.xcresult
TEST_RUNNER_SCREENSHOT_DIR="$OUT" xcodebuild -project PrayToScroll.xcodeproj -scheme PrayToScrollScreenshots \
  -destination "id=$SIM" -derivedDataPath build/dd -resultBundlePath build/ui.xcresult \
  -only-testing:PrayToScrollUITests/ScreenshotTests CODE_SIGNING_ALLOWED=NO test 2>&1 \
  | grep -E "error:|Test Case .*(passed|failed)|\*\* TEST" || true
ls -la "$OUT"
for f in "$OUT"/*.png; do sips -g pixelWidth -g pixelHeight "$f" | tail -2 | tr '\n' ' '; echo " $(basename "$f")"; done
