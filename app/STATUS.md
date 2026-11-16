# Status (2026-11-16)

## Verification so far

There is no Xcode on the Mac mini yet, so nothing has been built for a simulator or device and no UI test or
screenshot has run. What has been checked:

| Check | Result |
|---|---|
| `tools/typecheck.sh all`: app, widget (as an app extension), Strict Lock app + 3 extensions, unit tests, against the Mac Catalyst iOS frameworks | 0 errors. `FamilyActivitySelection` is iOS-only (expected under Catalyst) |
| `tools/run-unit-tests.sh`: 41 unit tests built and run as a Catalyst binary | 41 passed. A deliberately broken test fails, so the runner does catch failures |
| `xcodegen generate` (v1.0 and `project-strictlock.yml`) | Both generate; 3 schemes (PrayToScroll, PrayToScrollUnit, PrayToScrollScreenshots) |
| App icon `art/icon_1024.png` | 1024×1024, no alpha. Checked by eye at 512 and 60 px: the lamb reads at both |
| Home-screen label "Pray to Scroll" | Estimated, not seen: 75.1 pt at 12 pt system font, the same width as "Google Maps" (74.4). Probably fits; confirm on the simulator |

Blind spots of the no-Xcode check: the SwiftData `@Model` macro expansion (models are stubbed), iOS-only
SwiftUI/UIKit behaviour, asset catalog compilation, Info.plist/entitlement processing, linking, and all runtime
UI. The first real `xcodebuild` may still turn up a few errors.

## Done (code complete for v1.0)

- **Prayer Gate** via Shortcuts automations + App Intents (`Pray First`, per-app preset intents, `Pray Now`, `Tempted? Pray Now`).
  Loop-safe (30 s launch pass when the app reopens Instagram etc.), 20 s grace, window or Daily key unlock (reset hour),
  emergency pass once a day, pause 1/3/7 days, window-end notification.
- **Gate setup**: per-app checklist with status (not set up / waiting / protected / silent), a step-by-step guide with
  drawn Shortcuts screens, **Test my gate**, verified sheet, troubleshooter (7 checks).
- **Prayer session**: quick / guided ACTS / verse reveal / for someone; guided lengths 30 s to 5 min; mood chips incl. Tempted;
  timer pauses in the background; Amen disabled until the timer ends, then press-and-hold; A−/A+ text size; no-repeat prompt bag.
- **Celebration**: streak count-up, unlock countdown + "Continue to app", milestones, journal note, share cards.
- **Pray for someone**: people list, requests, mark answered, Answered wall, editable "let them know" message, answered share card.
- **Streaks** computed from the prayer log, a free weekly freeze ("Grace is free. We'll never sell streak freezes."),
  16-week heatmap, milestones with badges, time-reclaimed estimate.
- **Scroll the Word**: paging verse feed with drawn scenes, save, share, pray it.
- **Journal**, **Challenges** (prayed days / distinct people), **Reminders** (daily, streak at risk, morning verse).
- **Prayer Circles** (CloudKit public DB): create/join by code or link, weekly leaderboard, hide me, Leave (deletes my
  member row), Report (record + local block), Block, nickname filter, "Nicknames are visible to people in this circle.",
  erase my data. Schema: `CloudKit/schema.ckdb`.
- **Onboarding**: 12 steps incl. scroll quiz, the "mirror" (hours → days a year), a try-it sample prayer, app choice,
  style, window, reminders, name, gate setup, first prayer.
- **Settings/About**: "Free. No ads. No account. No tracking.", translation credit from `copy.json`, privacy/terms/support
  links (praytoscroll.vercel.app), erase all data.
- **Widgets**: streak (small + 3 lock-screen sizes), verse (medium/large), Pray now (small + circular).
- **Art**: icon + lamb (wave/phone/pray/celebrate/sleep), gold padlock and flame wired in, each with a SwiftUI fallback.
- **Strict Lock v1.1** (compiled out): Screen Time authorization + picker, shields, relock monitor, shield screen
  ("Pray first" / "Pray now"), shield action → tap-to-pray notification. See README to switch it on.
- **Tests**: 41 unit tests; UI tests = 5 flow checks + 10 screenshot tests (`01-home` … `10-someone`, `.keepAlways`).

## Not done / not working yet

- **Never built with Xcode.** Next: `xcodegen generate`, build on the 6.9" simulator, fix any errors, run unit + UI tests,
  `tools/screenshots.sh`, look at every screenshot, check the home-screen label.
- UI tests and screenshot routes are written but have never run; selectors may need adjusting.
- No widget screenshots (adding widgets to the simulator home screen isn't scriptable from XCTest).
- CloudKit schema isn't imported or deployed (needs Xcode `cktool` + a management token, and the Console's deploy to Production).
- Strict Lock needs Apple's Family Controls (Distribution) entitlement and profiles for 4 bundle IDs before it can ship.
- `Services/ProStore.swift` (StoreKit, future Pro) isn't reachable from any v1.0 screen.
- Content: copies of `../content/*.json` are current as of today. Re-copy them if the content changes.
