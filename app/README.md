# Pray to Scroll (iOS app)

SwiftUI app, iOS 17+, Swift 5 mode. The Xcode project is generated with XcodeGen (`*.xcodeproj` is gitignored).

| Target | What |
|---|---|
| `PrayToScroll` | The app (bundle `com.amenkeyapp.ios`, App Group `group.com.amenkeyapp.ios`, CloudKit `iCloud.com.amenkeyapp.ios`) |
| `PrayToScrollWidget` | Streak, verse and Pray now widgets (home + lock screen) |
| `PrayToScrollTests` | Unit tests (gate, streak + freeze, challenges, links, prompt bag, copy, name filter, bundled content) |
| `PrayToScrollUITests` | Flow checks + App Store screenshots (`ScreenshotTests`) |
| v1.1 only: `PrayToScrollShieldConfig`, `PrayToScrollShieldAction`, `PrayToScrollMonitor` | Strict Lock (Screen Time) extensions, in `project-strictlock.yml` |

The display name is set in one place: `APP_DISPLAY_NAME` in `project.yml` (code reads it via `AppConstants.appName`).
The web base for links (privacy, support, `join?c=CODE`) is `AKWebBase` in `project.yml`.

## Generate, build, test (needs Xcode)

```bash
brew install xcodegen          # once
cd app
xcodegen generate              # PrayToScroll.xcodeproj

SIM=$(bash ../ci/pick_sim.sh)  # best 6.9" iPhone simulator
xcodebuild -project PrayToScroll.xcodeproj -scheme PrayToScroll -destination "id=$SIM" CODE_SIGNING_ALLOWED=NO build
xcodebuild -project PrayToScroll.xcodeproj -scheme PrayToScrollUnit -destination "id=$SIM" CODE_SIGNING_ALLOWED=NO test
tools/screenshots.sh           # UI tests in -demo, 9:41 status bar, PNGs -> ../store/screenshots/raw/
```

The Mac mini is shared: check `pgrep -x xcodebuild` before building (`tools/screenshots.sh` waits by itself).

Signing: Debug/simulator builds are unsigned (`CODE_SIGN_STYLE: Manual`, simulator identity `-`). Release uses
"Apple Distribution" with the profiles "AmenKey AppStore" / "AmenKey Widget AppStore". Certificates and profiles
are managed outside this repo; never create or revoke anything with Apple from here.

## Without Xcode (Command Line Tools only)

```bash
tools/typecheck.sh all     # app, widget, Strict Lock app + 3 extensions, unit tests: "clean" or the errors
tools/run-unit-tests.sh    # builds the unit tests into a Mac Catalyst runner and runs them
```

They compile against the Mac Catalyst copies of the iOS frameworks in the CLT macOS SDK. The CLT has no SwiftData
macro plugin, so a scratch copy of the sources gets `@Model`/`@Query`/`#Predicate` swapped for stubs, and the tests
use a small XCTest stand-in (`tools/xctest-shim`). APIs Catalyst doesn't have (e.g. `FamilyActivitySelection`)
are listed but not counted as errors. It's a strong check, not a substitute for a real simulator build.

## Demo mode and screenshots

Launch arguments (scheme or UI tests):

- `-demo`: a seeded, in-memory demo (Mark, a 12-day streak, people, answered prayers, two circles). Never touches real data.
- `-uitest`: short prayer minimums (3 s, sample 2 s).
- `-onboarding`: with `-demo`, start at onboarding.
- `-route <name>`: open a screen: `pray`, `gatepray`, `quick`, `someone`, `choose`, `gate`, `people`, `answered`,
  `circle`, `stats`, `journal`, `word`, `settings`, `verified`, `troubleshoot`.
- `-appearance light|dark`.

`ScreenshotTests` saves `01-home` … `10-someone` as XCTest attachments (lifetime `.keepAlways`) and, when
`TEST_RUNNER_SCREENSHOT_DIR` is set, as PNGs in that folder.

## Art

`tools/import_art.sh` copies `../art/*.png` into `PrayToScroll/Resources/Assets.xcassets` (mascots downscaled to
600 px @3x; `icon_1024.png` must be opaque). Every illustration has a SwiftUI fallback (`MascotView`, `ArtImage`),
so a missing file never breaks a screen. `tools/make_icon.swift` draws a fallback icon in code.

## Content

`PrayToScroll/Resources/{verses,prompts,challenges,copy}.json` are copies of `../content/*.json`. Re-copy them when
the content files change. `copy.json` placeholders: `{name}` (user's first name, "friend" fallback), `{hours}`,
`{days}`, `{streak}`, `{verseRef}`, `{verseText}`; in `prompts.json`, `{name}` is the person being prayed for.

## Prayer Circles (CloudKit)

Public database, schema in `CloudKit/schema.ckdb` (import with `xcrun cktool import-schema`, then deploy to
Production in the CloudKit Console). Stored: circle name/code, nickname, emoji, weekly count, streak, under a random
per-install member id. Reports (`CircleReport`) are readable only in the Console: review them within 24 hours.

## Switching Strict Lock on (v1.1)

Strict Lock uses Screen Time (FamilyControls). It needs Apple's Family Controls (Distribution) entitlement approved
for `com.amenkeyapp.ios`, `.shieldconfig`, `.shieldaction` and `.monitor`, and matching provisioning profiles.
Until then it is compiled out: the sources in `StrictLock/` and `Shared/StrictLockStore.swift` only build with the
`STRICT_LOCK` flag.

```bash
xcodegen generate --spec project-strictlock.yml   # adds the 3 extensions + STRICT_LOCK + family-controls
```

That adds Settings → Strict Lock (Screen Time authorization, app picker, on/off). After each prayer the shields lift
for the unlock window and the monitor extension puts them back; if monitoring fails, the app re-shields on the next
launch. Go back to v1.0 with plain `xcodegen generate`.
