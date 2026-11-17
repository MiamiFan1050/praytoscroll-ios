#!/bin/bash
# Typechecks the app, the widget and the unit tests WITHOUT Xcode, against the Mac Catalyst iOSSupport
# frameworks in the Command Line Tools SDK. The CLT has no SwiftData/Foundation macro plugins, so a scratch
# copy of the sources gets @Model replaced by hand-written PersistentModel stubs and #Predicate by a shim.
# Usage: tools/typecheck.sh [app|widget|extensions|tests|all]   (prints "error:" lines; exit 0 = clean)
set -uo pipefail
cd "$(dirname "$0")/.."
APP="$(pwd)"
SDK=${SDK:-/Library/Developer/CommandLineTools/SDKs/MacOSX26.sdk}
WORK=${TMPDIR:-/tmp}/praytoscroll-typecheck
rm -rf "$WORK" && mkdir -p "$WORK"
cp -R PrayToScroll Shared PrayToScrollWidget StrictLock "$WORK/"
[ -d PrayToScrollTests ] && cp -R PrayToScrollTests "$WORK/"

python3 - "$WORK" <<'PY'
import os, re, sys
root = sys.argv[1]
stub = '''
    var persistentBackingData: any BackingData<{T}> {{ get {{ fatalError() }} set {{}} }}
    static var schemaMetadata: [Schema.PropertyMetadata] {{ [] }}
    init(backingData: any BackingData<{T}>) {{ fatalError() }}
'''
for dirpath, _, files in os.walk(root):
    for f in files:
        if not f.endswith('.swift'): continue
        p = os.path.join(dirpath, f)
        s = open(p).read()
        o = s
        s = re.sub(r'@Model\s*\n\s*final class (\w+) \{', lambda m: 'final class %s: PersistentModel {' % m.group(1) + stub.format(T=m.group(1)), s)
        s = re.sub(r'@Relationship\([^)]*\)\s*\n', '', s)
        s = re.sub(r'#Predicate<(\w+)>', r'shimPredicate(\1.self)', s)
        s = s.replace('#Predicate', 'shimPredicate')
        s = re.sub(r'@Query\b', '@ShimQuery', s)
        if s != o: open(p, 'w').write(s)
open(os.path.join(root, 'PrayToScroll', 'TypecheckShim.swift'), 'w').write('''import Foundation
func shimPredicate<T>(_ type: T.Type, _ body: (T) -> Bool) -> Predicate<T> { fatalError() }
func shimPredicate<T>(_ body: (T) -> Bool) -> Predicate<T> { fatalError() }
@propertyWrapper struct ShimQuery<Element> {
    var wrappedValue: [Element] { [] }
    init() {}
    init(filter: Predicate<Element>? = nil, sort: [SortDescriptor<Element>] = []) {}
    init<V: Comparable>(filter: Predicate<Element>? = nil, sort: KeyPath<Element, V>, order: SortOrder = .forward) {}
    init<V: Comparable>(filter: Predicate<Element>? = nil, sort: KeyPath<Element, V?>, order: SortOrder = .forward) {}
}
''')
PY

FLAGS=(-typecheck -swift-version 5 -sdk "$SDK" -target arm64-apple-ios17.0-macabi
       -Fsystem "$SDK/System/iOSSupport/System/Library/Frameworks")
what=${1:-all}
prep_tests() {
  cp "$APP/tools/xctest-shim/XCTestShim.swift" "$WORK/XCTestShim.swift"
  find PrayToScrollTests -name "*.swift" -exec sed -i '' -e 's/^@testable import PrayToScroll$//' -e 's/^import XCTest$/import Foundation/' \
    -e 's|Bundle(for: AppModel.self)|Bundle(path: "'"$APP"'/PrayToScroll/Resources")!|g' {} \;
  sed -i '' 's/^@main$//' PrayToScroll/App/PrayToScrollApp.swift
}
status=0
run() {
  local label=$1; shift
  local out
  out=$(xcrun swiftc "${FLAGS[@]}" "$@" 2>&1 | grep -E "^[^ |].*error:" | sed "s|$WORK/||" | sort -u)
  # "unavailable in Mac Catalyst" = an iOS-only API (e.g. FamilyActivitySelection), fine on iOS: listed, not failed.
  local catalyst real
  catalyst=$(echo "$out" | grep "unavailable in Mac Catalyst" || true)
  real=$(echo "$out" | grep -v "unavailable in Mac Catalyst" | grep . || true)
  if [ -n "$real" ]; then echo "== $label: $(echo "$real" | wc -l | tr -d ' ') errors"; echo "$real"; status=1; else echo "== $label: clean"; fi
  if [ -n "$catalyst" ]; then echo "   ($(echo "$catalyst" | wc -l | tr -d ' ') iOS-only APIs Catalyst can't see: $(echo "$catalyst" | sed -E "s/.*error: '([^']+)'.*/\1/" | sort -u | tr '\n' ' '))"; fi
}
cd "$WORK"
# Both builds: the default (no Screen Time) and project-strictlock.yml's STRICT_LOCK.
if [ "$what" = app ] || [ "$what" = all ]; then
  run app -D DEBUG $(find PrayToScroll Shared -name "*.swift")
  run app-release $(find PrayToScroll Shared -name "*.swift")
  run app-strict -D DEBUG -D STRICT_LOCK $(find PrayToScroll Shared -name "*.swift")
  run app-strict-release -D STRICT_LOCK $(find PrayToScroll Shared -name "*.swift")
fi
if [ "$what" = widget ] || [ "$what" = all ]; then
  run widget -application-extension $(find PrayToScrollWidget Shared -name "*.swift" ! -name StrictLockStore.swift)
fi
if [ "$what" = extensions ] || [ "$what" = all ]; then
  # The three Screen Time extensions (shield look, shield buttons, relock monitor).
  for ext in ShieldConfiguration ShieldAction DeviceActivityMonitor; do
    run "ext-$ext" -application-extension -parse-as-library -D STRICT_LOCK $(find "StrictLock/$ext" Shared -name "*.swift")
  done
fi
if { [ "$what" = tests ] || [ "$what" = all ]; } && [ -d PrayToScrollTests ]; then
  # Unit tests compile against the app sources directly, with a small XCTest stand-in (no XCTest in the CLT).
  prep_tests
  run tests -D DEBUG $(find PrayToScroll Shared PrayToScrollTests -name "*.swift") "$WORK/XCTestShim.swift"
  run tests-strict -D DEBUG -D STRICT_LOCK $(find PrayToScroll Shared PrayToScrollTests -name "*.swift") "$WORK/XCTestShim.swift"
fi
exit $status
