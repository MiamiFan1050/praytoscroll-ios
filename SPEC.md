# AmenKey (folder name: praypass) — product + build spec (v1.0)

**RENAMED 2026-11-16: "PrayPass" is taken on the App Store and com.praypass.app is taken. The app is AmenKey everywhere: display name AmenKey, store name `AmenKey: Pray to Unlock`, bundle com.amenkeyapp.ios (+ .widget, .shieldconfig, .shieldaction, .monitor, all registered), App Group group.com.amenkeyapp.ios, CloudKit iCloud.com.amenkeyapp.ios, URL scheme amenkey://. Brand idea: "Amen is the key". The press-and-hold Amen that unlocks your apps is the signature moment. Icon: a gold key whose bow is an arched doorway with a small cross of light, on the midnight gradient. Where this spec says PrayPass, read AmenKey.**

Owner: Mark Morrison (individual Apple developer, team ZV8C94YFWU, seller "Mark Morrison").
Goal: a genuinely excellent iOS app, live on the App Store. Mark's words: "copy all the features [of the
prayer-lock apps], make them better, add features… make an amazing app." Not a conservative MVP.

## One-line pitch
**Pray first. Scroll after.** Your distracting apps wait until you've prayed, and you can pray for
someone to unlock and let them know.

Store name: `PrayPass: Pray Before You Scroll` is 32 chars, over the 30-char limit, so use
**`PrayPass: Pray to Unlock`** with subtitle **"Pray first. Scroll after."**
Bundle prefix: `com.amenkeyapp.ios`. App Group: `group.com.amenkeyapp.ios`. URL scheme: `amenkey://`.

## Why v1 does NOT use Screen Time (FamilyControls)
App Store / TestFlight distribution of FamilyControls needs Apple's hand-approved "Family Controls
(Distribution)" entitlement. Mark still has to click the request button himself, and approval takes days
to weeks. So:
- **v1.0 ships the "Prayer Gate"**, built on Shortcuts automations + App Intents with no entitlement
  (the pattern one sec / ScreenZen shipped with): "When Instagram is opened → run PrayPass › Pray First".
  The intent checks the shared unlock window. If you're unlocked it returns silently and you stay in
  Instagram. If not, it continues in the foreground: PrayPass opens on the prayer screen. After the prayer,
  a "Continue to Instagram" button opens the app via its URL scheme, and the gate stays quiet for the
  chosen window (5/15/30/60 min).
- **v1.1 adds "Strict Lock"** (FamilyControls shields + ShieldConfiguration/ShieldAction/DeviceActivityMonitor
  extensions) once Apple approves. WRITE THIS CODE NOW, but keep it out of the v1 build: put it in
  `app/StrictLock/` (3 extension targets + `ScreenTimeService.swift`) behind an XcodeGen option /
  `STRICT_LOCK` compile flag, with no family-controls entitlement in the v1 targets. The UI shows Strict
  Lock as "Coming soon" in v1 (never a broken button).

## Features (v1.0, all real, all working)
1. **Onboarding** (premium, 9–11 screens, skippable at the end only): welcome → "How many hours a day do
   you scroll?" quiz (slider) → the mirror ("That's N days a year" with real math) → the promise →
   choose apps (Instagram, TikTok, YouTube, X, Snapchat, Facebook, Reddit, Threads, Pinterest, plus a custom
   URL scheme) → unlock style → unlock window → reminders (notification permission) → first name → set up
   the gate (guided Shortcuts setup, below) → first prayer, right now.
2. **Prayer Gate setup**: a beautiful step-by-step guide per app with a "Open Shortcuts" button
   (`shortcuts://create-automation` if it works, else `shortcuts://`), large numbered steps, illustrated
   mock screens drawn in SwiftUI (no screenshots of Apple UI), plus a checklist that verifies: the first time
   the intent fires for an app, mark it "Protected ✓" (store the per-app last-fired date in the app group).
3. **Prayer session** (the heart of the app; must feel calm and premium): full screen, slow breathing
   glow, a timer ring. Unlock styles:
   - *Quick prayer* (30 s): one prompt + Amen.
   - *Guided* (1–3 min): ACTS steps (Adoration, Confession, Thanksgiving, Supplication), each with a
     rotating prompt.
   - *Verse + prayer*: read today's verse (tap to reveal one line at a time), then pray it.
   - *Pray for someone* (the twist): pick a person from your Prayer List or Contacts (CNContactPickerViewController,
     no Contacts permission needed), get a prompt, pray. At the end: "Let Sarah know?" → MFMessageComposeViewController
     prefilled "I just prayed for you 🙏" + the app link (or the share sheet if Messages isn't available).
   Finish = **press-and-hold "Amen"** (1.2 s, haptic ramp). Then the celebration: streak +1 animation, soft
   light particles, "Unlocked for 15 min", a "Continue to [App]" button, and an optional one-line journal
   ("What's on your heart?").
4. **Home**: greeting by name and time of day, a status card (Gate ON · Unlocked 12:34 left · or Locked), a
   streak flame with a number, today's verse card (share), a big "Pray now" button, today's stats, a
   people-to-pray-for preview, and a circle preview.
5. **Prayer List / People**: people (name, relationship, emoji or initials avatar) with requests; "last prayed"
   dates; "Pray for someone" picks whoever was prayed for longest ago; requests can be marked
   **Answered** and go on the Answered Prayers wall (the emotional retention feature).
6. **Journal**: dated entries from sessions + free entries; search; linked person or request.
7. **Streaks + stats**: current and longest streak, calendar heatmap, milestones (3, 7, 14, 21, 30, 50, 100,
   365 days) with badges, **1 streak freeze per week**, totals (prayers, minutes prayed, people prayed for,
   gates honoured = "times you prayed instead of scrolling"), and an estimated "time reclaimed".
8. **Competitions**:
   - **Prayer Circles** (friends leaderboard): create a circle → 6-char code + share link
     (`https://<pages-domain>/join?c=CODE` → `amenkey://join?c=CODE`), join by code, a weekly leaderboard
     (prayers this week, streak), and encouragement (send "praying for you" via the share sheet). Backend:
     **CloudKit public database**, container `iCloud.com.amenkeyapp.ios`, behind a `CircleService` protocol with a
     `CloudKitCircleService` and a `MockCircleService` (demo mode / no iCloud). If iCloud isn't signed in, show a
     friendly explainer, never a crash.
   - **Challenges** (solo, offline): 7-day Fresh Start, 21-day Habit, 40-day Social Media Fast, 30-day Pray for 30
     People; progress rings, badges, start/abandon.
9. **Share cards** (the viral loop): ImageRenderer cards for streak milestones, today's verse and "I prayed
   instead of scrolling N times" → share sheet (Instagram Stories friendly, 1080×1920).
10. **Emergency pass**: once a day, "I need it now" opens your app for 5 minutes without praying (counted
    honestly in stats). It's the escape hatch reviewers and users expect.
11. **Reminders**: daily prayer time, "streak at risk" at 8 pm if no prayer today, a gentle morning verse.
    All local notifications.
12. **Widgets** (WidgetKit target `com.amenkeyapp.ios.widget`): small streak, medium verse of the day, a lock-screen
    circular streak, and a "Pray now" deep link. Data via the app group.
13. **Settings**: the gated apps list + setup status, unlock style, window, reminders, name, Strict Lock "Coming
    soon", Bible translation note (World English Bible, public domain), privacy policy, terms, support, rate the
    app, reset all data (confirm).
14. **Deep links**: `amenkey://pray`, `amenkey://pray?app=instagram`, `amenkey://join?c=CODE`, `amenkey://challenge/<id>`.
15. **Demo mode**: launch argument `-demo` (also used by UI tests): seeded name ("Mark"), a 12-day streak,
    people, journal, a mock circle of 6 members and gates marked protected, so every screen looks alive for
    screenshots. Never visible to real users.

No paywall in v1: the Paid Apps Agreement isn't signed. Everything is free. Keep a `Store` abstraction
(StoreKit 2) stubbed for v1.1 Pro, unreachable from the UI.

## Content (`app/PrayPass/Resources/`)
- `verses.json`: 366 entries `{ "day": 1, "ref": "Psalm 46:10", "text": "...", "theme": "peace" }`, World
  English Bible (public domain) text fetched from `https://bible-api.com/<ref>?translation=web`. Never typed
  from memory.
- `prompts.json`: `{ "adoration": [..], "confession": [..], "thanksgiving": [..], "supplication": [..], "quick": [..], "forSomeone": [..] }`,
  ≥25 original prompts per key; warm, plain English, never preachy; supplication/forSomeone use `{name}`.
- `challenges.json`: id, title, days, description, daily tip list.
- `copy.json` (optional): onboarding + notification strings.

## Design system (it must look like a top-10 paid app, not a template)
- Palette: Midnight `#0E1726`, Ink `#16233A`, Gold `#E9B949`, Warm Gold `#F5D58A`, Cream `#FBF6EC`, Sage `#A8C3A0`,
  Rose `#E7A6A1`; dark-first, with a beautiful light mode too.
- Type: display = New York (`.fontDesign(.serif)`), bold for big numbers; body = SF Pro Rounded. Generous spacing.
- Motion: spring transitions, a slow breathing glow in sessions, matched-geometry streak flame, haptics on key
  taps, reduced-motion respected.
- Components: GlassCard, PrimaryButton (gold, press-scale + haptic), HoldToConfirmButton, StatTile, StreakFlame,
  ProgressRing, Chip, EmptyState with a warm illustration in SwiftUI shapes.
- App icon: drawn in code (Python/Pillow or a Swift script), 1024×1024 RGB with no alpha. A midnight gradient with
  a glowing gold arched doorway (the "pass") and a small cross of light inside. Clean at 40 px.
- Accessibility: Dynamic Type to XXL without truncation of key text, VoiceOver labels, 44 pt targets.

## Tech
- iOS 17.0+, Swift 5.10/6, SwiftUI, Observation, SwiftData (people, requests, journal, sessions); app-group
  UserDefaults for gate state shared with the App Intent, the widget and (v1.1) the extensions.
- XcodeGen `app/project.yml` → `PrayPass.xcodeproj`. Targets: PrayPass, PrayPassWidget, PrayPassTests,
  PrayPassUITests; StrictLock targets only when the option is on.
- App Intents: `PrayFirstIntent` (parameter: AppEntity for the gated app), with Shortcuts phrases; continue in the
  foreground when a prayer is needed (iOS 17/18 API; use whatever compiles and works on the installed SDK);
  `PrayNowIntent`; an `AppShortcutsProvider`.
- `LSApplicationQueriesSchemes`: instagram, tiktok (snssdk1233), youtube, twitter/x, snapchat, fb, reddit, barcelona
  (Threads), pinterest.
- Info.plist: no unused usage strings. Contacts goes through the picker (no permission). Notifications are
  requested in onboarding. `ITSAppUsesNonExemptEncryption = NO`.
- Tests: unit tests (streak + freeze logic, unlock windows across midnight, gate decisions, milestone awards,
  challenge progress, circle code generation) and UI tests in `-demo` that walk onboarding → prayer → unlock and
  capture App Store screenshots on the iPhone 6.9" simulator (1320×2868).

## Shared machine rules
- Xcode is being installed by another session (IBFlash) via `mas`. Builds are serialized across sessions: before
  ANY xcodebuild, check `pgrep -x xcodebuild` and that `/Applications/Xcode.app` exists. viral-29 coordinates the
  slot with the IBFlash session (`ibflash-fe [8d2d33]`).
- Never touch ~/splitsnap*, ~/ibflash*, ~/.appstoreconnect/splitsnap (read-only signing material) or any other
  project. Never create or revoke certificates. Never print secrets.
- Code-made art only (no AI image generation).
