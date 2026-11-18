# Releasing 1.2 (Strict Lock) the day Apple approves Family Controls

Branch `v1.2`. The build is `app/project-strictlock.yml` (STRICT_LOCK on, version 1.2): the app, the widget and the
3 Screen Time extensions. Everything below is ready except what only Apple's approval unlocks: the Family Controls
(Distribution) capability on the App IDs, the 4 profiles that carry it, and their secrets.

Request: Family Controls (Distribution), team ZV8C94YFWU, Request ID **S7N7QC6BD5** (2026-11-16, for the whole team).
Profiles and certificates are made by viral-29 (the agent that owns signing); no one else creates or revokes anything.

## 0. Before Apple answers (done, re-check if the branch moved)

```sh
cd app && tools/typecheck.sh all && STRICT_LOCK=1 tools/run-unit-tests.sh   # run one after the other, never together
```

Both must end clean (`== …: clean` on every line, `N tests, 0 failures`). The strict job of `ci.yml` (unit tests and an
unsigned Release compile of the lock build) is the remote check; run it once on `v1.2` when Actions minutes allow:
`gh workflow run ci.yml --repo MiamiFan1050/praytoscroll-ios --ref v1.2`.

## 1. The approval email arrives

Check it says Family Controls (Distribution) is approved for the team (or names the bundle IDs). If it names only
`com.amenkeyapp.ios`, request it for `.shieldconfig`, `.shieldaction` and `.monitor` too (same form) before going on:
an extension without it can't be signed.

## 2. Capabilities, per App ID (developer.apple.com › Certificates, IDs & Profiles › Identifiers)

| App ID | Capabilities it needs | Change |
|---|---|---|
| `com.amenkeyapp.ios` | App Groups (`group.com.amenkeyapp.ios`), iCloud (CloudKit, `iCloud.com.amenkeyapp.ios`), **Family Controls** | add Family Controls |
| `com.amenkeyapp.ios.widget` | App Groups (`group.com.amenkeyapp.ios`) | none |
| `com.amenkeyapp.ios.shieldconfig` | App Groups (`group.com.amenkeyapp.ios`), **Family Controls** | register the App ID if missing, then both |
| `com.amenkeyapp.ios.shieldaction` | App Groups (`group.com.amenkeyapp.ios`), **Family Controls** | same |
| `com.amenkeyapp.ios.monitor` | App Groups (`group.com.amenkeyapp.ios`), **Family Controls** | same |

Family Controls has a Development / Distribution choice once approved: pick **Distribution** for the App Store.
(These match the entitlements files: `PrayToScroll/PrayToScroll-StrictLock.entitlements` and
`StrictLock/*/{ShieldConfig,ShieldAction,Monitor}.entitlements`.)

## 3. Profiles (App Store, Apple Distribution certificate)

The names must match exactly: `project.yml` / `project-strictlock.yml` sign by name, and so does
`ci/ExportOptions-strictlock.plist`.

| Profile name | App ID | Change |
|---|---|---|
| `AmenKey AppStore` | `com.amenkeyapp.ios` | Edit › Save to regenerate it after step 2 (the old one turns Invalid) |
| `AmenKey ShieldConfig AppStore` | `com.amenkeyapp.ios.shieldconfig` | new |
| `AmenKey ShieldAction AppStore` | `com.amenkeyapp.ios.shieldaction` | new |
| `AmenKey Monitor AppStore` | `com.amenkeyapp.ios.monitor` | new |
| `AmenKey Widget AppStore` | `com.amenkeyapp.ios.widget` | none |

Check each new one lists `com.apple.developer.family-controls` under Entitlements before downloading it.

## 4. Repo secrets (MiamiFan1050/praytoscroll-ios › Settings › Secrets › Actions)

Base64 of each `.mobileprovision`, piped so nothing is printed. The existing names stay as they are.

| Secret | Holds | Status |
|---|---|---|
| `FC_APP_PROFILE_B64` | `AmenKey AppStore` (regenerated, with Family Controls) | **new** |
| `FC_SHIELDCONFIG_PROFILE_B64` | `AmenKey ShieldConfig AppStore` | **new** |
| `FC_SHIELDACTION_PROFILE_B64` | `AmenKey ShieldAction AppStore` | **new** |
| `FC_MONITOR_PROFILE_B64` | `AmenKey Monitor AppStore` | **new** |
| `APP_PROFILE_B64` | `AmenKey AppStore` | **replace** with the regenerated file too (the old one is Invalid now; a 1.1.x build would fail without it) |
| `WIDGET_PROFILE_B64`, `DIST_P12_B64`, `DIST_P12_PASSWORD`, `KEYCHAIN_PASSWORD`, `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_P8_B64` | as today | unchanged |

```sh
R=MiamiFan1050/praytoscroll-ios
base64 -i "AmenKey_AppStore.mobileprovision"              | gh secret set FC_APP_PROFILE_B64          --repo $R
base64 -i "AmenKey_AppStore.mobileprovision"              | gh secret set APP_PROFILE_B64             --repo $R
base64 -i "AmenKey_ShieldConfig_AppStore.mobileprovision" | gh secret set FC_SHIELDCONFIG_PROFILE_B64 --repo $R
base64 -i "AmenKey_ShieldAction_AppStore.mobileprovision" | gh secret set FC_SHIELDACTION_PROFILE_B64 --repo $R
base64 -i "AmenKey_Monitor_AppStore.mobileprovision"      | gh secret set FC_MONITOR_PROFILE_B64      --repo $R
gh secret list --repo $R   # names and dates only
```

## 5. Build and upload

```sh
gh workflow run release.yml --repo MiamiFan1050/praytoscroll-ios --ref v1.2 -f strict_lock=true
gh run watch --repo MiamiFan1050/praytoscroll-ios $(gh run list --repo MiamiFan1050/praytoscroll-ios --workflow release.yml --limit 1 --json databaseId -q '.[0].databaseId')
```

`strict_lock` defaults to true on this branch. The run stops early, with the name of what's wrong, if:
a secret is missing; a profile is for another bundle ID; one of the 4 Family Controls profiles lacks the
entitlement; or the archive isn't version 1.2 with exactly the 4 extensions (Monitor, ShieldAction, ShieldConfig,
Widget), each Screen Time one signed with Family Controls. The build number is the run number. The upload goes to
App Store Connect; processing takes about 15–30 minutes.

## 6. Prove the lock on a real iPhone (TestFlight, 20 minutes, before submitting)

The Simulator can't show Apple's shields, so this is the one check CI can't do.

1. Install the TestFlight build. Onboarding › Choose apps › allow Screen Time › pick one app (e.g. Photos).
2. Open it: "Pray to open". Pray now › notification › pray › hold Amen. Home: "Unlocked", and the line
   **"Lock check: relock set for …"**.
3. Close Pray to Scroll and use the app. At the time shown it locks again by itself. Home now reads
   **"Lock check: on. Locked again by itself at …"** (the monitor extension wrote that time, so it's the proof).
4. Settings › Screen Time › Apps with Screen Time Access › turn Pray to Scroll off. Home: **"Screen Time access is
   off"**, nothing is locked. "Turn on" asks again and the lock comes back.
5. Optional: pray, restart the iPhone, open Pray to Scroll (the timer is restarted if iOS lost it), wait for the end.

If step 3 doesn't relock, don't submit: send the run number and what Home's lock check said.

## 7. Store listing and submission

The 1.2 copy is drafted in `store/v1.2/metadata/` (not live). Copy it over the live folder, then run the store lane
(from `~/praypass`, with the ASC key environment shown at the top of `fastlane/Fastfile`):

```sh
cp store/v1.2/metadata/en-US/*.txt store/metadata/en-US/
cp store/v1.2/metadata/review_information/notes.txt store/metadata/review_information/notes.txt
fastlane ios store version:1.2                        # listing only: check it in App Store Connect
fastlane ios store version:1.2 submit:true build:N    # N = the release run's number
```

- Subtitle "Lock apps until you pray"; the description, promotional text, keywords and "What's New" say *locks*,
  which is now true (Screen Time shields).
- App Privacy stays "Data Not Collected": the picked apps are opaque Screen Time tokens kept on the device, and no
  usage data is read.
- Screenshots: the 1.1 set stays (the Simulator can't capture the system shield). A real-device screenshot of the
  "Pray to open" shield can be added later.
- The review notes (`store/v1.2/metadata/review_information/notes.txt`) explain the Family Controls use: `.individual`
  authorization on the user's own device, FamilyActivityPicker tokens only, ManagedSettings shields, the shield's
  "Pray now" notification, DeviceActivity relocking, every way out (gate off, emergency pass, pause, Screen Time
  settings), the fail-open "Lock paused" state, and a 2-minute test (relock after 15 minutes).

## What the lock does when things go wrong (audit 2026-11-17)

The lock fails **open**, never closed, and never silently. Every case is a unit test in
`PrayToScrollTests/LockFailureTests.swift` (a simulated iPhone with Apple's rules, running the real
`RelockEngine`) or `ShieldPlannerTests.swift`; the app wiring is in `LockLifecycleTests.swift` (CI only).

| Failure | What happens |
|---|---|
| `startMonitoring` throws (any `MonitoringError`) | apps open anyway; Home "Lock paused, tap to fix"; a notification at the window's end; the next sync (opening or leaving the app) retries, or locks at once if the window is over |
| Window under 15 min (Apple's `intervalTooShort`) | never asked for: the interval is ≥ 15 min and its end *warning* lands on the window's end |
| A week's pause (`intervalTooLong`) | covered in ≤ 6-day legs; the monitor starts the next leg itself (a refused leg shows "Lock paused") |
| Over 20 activities | one activity name in the whole app, replaced each time; if Apple refused anyway, fail open + shown |
| App killed mid-unlock | the timer starts before the shield comes down; the next launch opens what the Amen paid for |
| Reboot / iOS update drops the timer | a timer that's missing, moved or finished-without-a-callback reads as not running; the next sync starts it again |
| iOS never calls the monitor | every relock has two callbacks (warning at the end, interval end a minute later) and a safety notification 3 minutes after, withdrawn when the monitor relocks |
| Time-zone change | schedules are wall-clock, so the app re-checks on `NSSystemTimeZoneDidChange` and every open; eastward with the app closed relocks on time (the early end re-arms); **westward with the app closed can relock late by up to the time difference** (the safety notification still fires on time) |
| Screen Time access revoked / reset by an iOS update | shields lifted (never stuck locked); Home "Screen Time access is off" with "Turn on"; the lock comes back when access does; iOS 26.4's `approvedWithDataAccess` counts as approved |

Known limit left: if iOS never calls the monitor **and** notifications are off, the apps stay open until Pray to
Scroll is next opened or left (that sync locks them).
