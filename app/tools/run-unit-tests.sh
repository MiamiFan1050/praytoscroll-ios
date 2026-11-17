#!/bin/bash
# Builds the unit tests + app sources into a Mac Catalyst command-line runner and RUNS them, without Xcode.
# Uses the same scratch copy as tools/typecheck.sh (SwiftData macro stubs + the XCTest stand-in).
# Tests that need a real SwiftData store or iOS UI don't belong in PrayToScrollTests anyway.
# STRICT_LOCK=1 tools/run-unit-tests.sh runs them against the project-strictlock.yml build (Screen Time code in).
set -uo pipefail
cd "$(dirname "$0")/.."
APP="$(pwd)"
SDK=${SDK:-/Library/Developer/CommandLineTools/SDKs/MacOSX26.sdk}
WORK=${TMPDIR:-/tmp}/praytoscroll-typecheck
"$APP/tools/typecheck.sh" tests >/dev/null || { echo "typecheck failed: run tools/typecheck.sh tests"; exit 1; }
cd "$WORK"
STRICT=${STRICT_LOCK:-}
python3 - "$WORK" "$STRICT" > "$WORK/main.swift" <<'PY'
import os, re, sys
root = sys.argv[1]
strict = sys.argv[2] == "1"
print("import Foundation")
print("var ran = 0")
print("func runCase<T: XCTestCase>(_ type: T.Type, _ name: String, _ body: (T) throws -> Void) {")
print("    let t = type.init(); t.name = name; ShimResults.current = name; ran += 1")
print("    t.setUp()")
print("    do { try body(t) } catch { ShimResults.fail(\"threw \\(error)\", #filePath, #line) }")
print("    t.tearDown()")
print("}")
for dirpath, _, files in sorted(os.walk(os.path.join(root, "PrayToScrollTests"))):
    for f in sorted(files):
        if not f.endswith(".swift"): continue
        src = open(os.path.join(dirpath, f)).read()
        if "HOSTED-ONLY" in src.split("\n", 1)[0]: continue
        if "STRICT_LOCK-ONLY" in src.split("\n", 1)[0] and not strict: continue
        for cls in re.finditer(r"class (\w+): XCTestCase \{(.*?)\n\}", src, re.S):
            for m in re.finditer(r"func (test\w+)\(\)( throws)?", cls.group(2)):
                print(f'runCase({cls.group(1)}.self, "{cls.group(1)}.{m.group(1)}") {{ try $0.{m.group(1)}() }}')
print('print("\\(ran) tests, \\(ShimResults.failures.count) failures")')
print('ShimResults.failures.forEach { print("FAIL", $0) }')
print('exit(ShimResults.failures.isEmpty ? 0 : 1)')
PY
DEFINES=(-D DEBUG -D NO_SCREEN_TIME)
[ "$STRICT" = 1 ] && DEFINES+=(-D STRICT_LOCK)
xcrun swiftc -swift-version 5 -Onone "${DEFINES[@]}" -sdk "$SDK" -target arm64-apple-ios17.0-macabi \
  -Fsystem "$SDK/System/iOSSupport/System/Library/Frameworks" \
  -L "$SDK/System/iOSSupport/usr/lib/swift" \
  -module-name PrayToScrollTestRunner -o "$WORK/test-runner" \
  $(find PrayToScroll Shared PrayToScrollTests -name "*.swift") "$WORK/XCTestShim.swift" "$WORK/main.swift" 2>&1 \
  | grep -E "error|undefined" | head -40
[ -x "$WORK/test-runner" ] || { echo "runner did not build"; exit 1; }
"$WORK/test-runner"
