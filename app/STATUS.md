# Status (2026-11-16)

## Verification

GitHub Actions CI (`.github/workflows/ci.yml`, macos-15, Xcode 26.3, iPhone 17 Pro Max simulator on iOS 26.2) is green:
run 43894331671 (and 43892715649 before the screenshot polish).

| Check | Result |
|---|---|
| `xcodegen generate` + Debug simulator build | Succeeded |
| Unit tests (`PrayToScrollUnit`) | 41/41 passed |
| UI tests (`PrayToScrollScreenshots`) | 16/16 passed: 5 flow checks + 10 store screenshots + the home-label shot |
| Release build for generic iOS (unsigned) | Succeeded |
| Store screenshots | `../out/ci-43894331671/named/01-home … 10-someone.png`, 1320×2868 (6.9"), reviewed by eye |
| Home-screen label "Pray to Scroll" | Fits untruncated on the 6.9" home screen (`99-home-label.png`). Measures 75.1 pt, like "Google Maps", so it should fit on 6.1" too. That's unverified |
| App icon `art/icon_1024.png` | 1024×1024, no alpha. Checked at 512 px, at 60 px and on the simulator home screen |

Without Xcode: `tools/typecheck.sh all` (Catalyst SDK) is clean and `tools/run-unit-tests.sh` passes 41/41.

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

- No widget screenshots (adding widgets to the simulator home screen isn't scriptable from XCTest).
- Signed archive/upload (`release.yml`) not run yet: it waits for the App Store Connect app record.
- CloudKit schema isn't imported or deployed (needs `cktool` + a management token, and the Console's deploy to Production).
  Circles were only exercised against the demo mock.
- Strict Lock needs Apple's Family Controls (Distribution) entitlement and profiles for 4 bundle IDs before it can ship.
- `Services/ProStore.swift` (StoreKit, future Pro) isn't reachable from any v1.0 screen.
- Content: copies of `../content/*.json` are current as of today. Re-copy them if the content changes.
