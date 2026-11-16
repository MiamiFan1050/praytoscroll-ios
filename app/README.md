# Pray to Scroll (iOS app)

SwiftUI app, iOS 17+, Swift 5 mode. The Xcode project is generated with XcodeGen (`*.xcodeproj` is gitignored).

| Target | What |
|---|---|
| `PrayToScroll` | The app (bundle `com.amenkeyapp.ios`, App Group `group.com.amenkeyapp.ios`, CloudKit `iCloud.com.amenkeyapp.ios`) |
| `PrayToScrollWidget` | Streak, verse and Pray now widgets (home + lock screen) |
| `PrayToScrollTests` | Unit tests (gate, streak + freeze, challenges, links, prompt bag, copy, name filter, bundled content) |
| `PrayToScrollUITests` | Flow checks + App Store screenshots (`ScreenshotTests`) |
| `PrayToScrollShieldConfig`, `PrayToScrollShieldAction`, `PrayToScrollMonitor` (v1.1) | Screen Time lock: the shield's look ("Pray to open TikTok"), its Pray now button (posts a notification that opens the prayer), the relock when a window ends |

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
  `circle`, `stats`, `journal`, `word`, `settings`, `verified`, `troubleshoot`, `friends`.
- `-noUsername`: with `-demo`, start without a @username (the demo friends @grace, @sam_p, @jordan_k and @hannah_b
  still exist to find; @grace is taken).
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

v1.1 adds prayer requests (`CirclePrayerRequest`: a topic + an optional 80-character line that `RequestNoteFilter`
checks for links, phone numbers, handles and blocked words) and `CirclePrayed` (one "I prayed 🙏" row per member per
request, counted once per iCloud account). Requests show for 7 days; there are no replies or messages. Each request
has Report (to `CircleReport`, reason prefixed `Prayer request <id>:`) and Block. To remove one, delete its record in
the Console. The App Store privacy label needs "Other User Content" (linked, App Functionality) before v1.1 ships.

## Usernames + friends (v1.1, CloudKit)

Optional @username (3–20 of a–z 0–9 _, case-insensitive, `UsernameRules`: reserved list + the nickname filter; one
change every 30 days). Same public database, record types in `CloudKit/schema.ckdb`:

- `Username`: recordName = the lowercase handle, so a second save of the same name fails (the claim is atomic).
  World-readable with no queryable field, so it can only be fetched by typing the exact name: there is no directory.
- `FriendProfile` (nickname, emoji, streak, owned circles), `FriendRequest`, `FriendLink` (one per side; a friendship
  is both links), `PrayedFor` (one per friend per day), `FriendBlock`: signed-in iCloud users only, fetched by record
  name or exact id. Reports go to `CircleReport` with circleCode `friends`.

Friends add each other by exact @username or the profile link `https://praytoscroll.vercel.app/u/<name>`
(`site/u.html` + the `site/vercel.json` rewrite; a plain page with an Open button and the App Store button, since
the app has no associated-domains entitlement for universal links). There are no messages: the only thing a friend
can send is "prayed for you", shown in the app on the next open (push would need the aps-environment entitlement).
Erase All Data deletes the username, profile, links, requests, prayed-for rows and blocks
(`CloudKitFriendService.deleteMyData`). `MockFriendService` (Debug only) has the same rules for UI tests.

## The Screen Time lock (v1.1)

The picked apps are locked with Screen Time (FamilyControls `.individual`, ManagedSettings shields, a
DeviceActivity relock timer). The Shortcuts gate is the fallback when Screen Time access is declined.

- `Shared/ShieldPlanner.swift`: every decision (pure, unit-tested in `ShieldPlannerTests`, incl. a simulated-device
  property test). Apple's schedules span at least 15 minutes, so under Screen Time every window (and the emergency
  pass, and a Daily key near its reset) is at least 15 minutes and the UI says so. The relock timer is started
  BEFORE a shield comes down; if Screen Time refuses it, the apps stay locked and the app shows why.
- `Shared/StrictLockStore.swift`: the shield, the picked tokens and the timer, shared by the app and the extensions.
- `PrayToScroll/Services/AppLock.swift`: the app's lock API: `ScreenTimeLock` (real), `DemoLock` (Debug only:
  the simulator can't show Apple's picker or shields), and a stub for the Catalyst unit runner (`NO_SCREEN_TIME`,
  set only by `tools/run-unit-tests.sh`).

Signing a Release build needs Family Controls (Distribution) approved for `com.amenkeyapp.ios`, `.shieldconfig`,
`.shieldaction` and `.monitor`, and App Store profiles with that capability for all four (names in `project.yml`).
