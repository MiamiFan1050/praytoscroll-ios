# AmenKey: competitor research (read 2026-11-16)

Scope: 17 pray/read-to-unlock apps, 3 secular gates (one sec, ScreenZen, Opal), 3 faith leaders (Hallow, Glorify, YouVersion).
Data comes from US App Store pages, the iTunes Search/Lookup API, the App Store review RSS (the ~100–150 most recent reviews for the big apps), developer sites and teardown sites. reddit.com was blocked to our tools, so there are no Reddit quotes. Ratings are as of today.
Legend: **Y** = has it, free · **$** = paid only · **-** = none / not listed · **?** = not stated · **ST** = Screen Time (FamilyControls) · **SC** = Shortcuts automation.

## 0. The market in one screen

- **The category exploded in 2026.** 216 faith "app blockers" turn up in US search (156 Christian). 187 of them launched in 2026, and only 3 before 2025. 129 have "Pray" in the name, 156 have "Lock", and 39 are literally "Prayer Lock" or "PrayLock" variants.
- **Every prayer-lock app uses Screen Time. None uses Shortcuts.** AmenKey v1 would be the only Shortcuts gate in the category. It's weaker as a lock, but it needs no Screen Time permission. That also means none of the "can't delete the app / locked out with no prayer" bugs that fill these apps' 1-star reviews.
- **The leaders by ratings:**
  - Bible Mode: 4.9★, 12.9K
  - BibleScroll: 4.8★, 10.1K (#11 Top Free Reference)
  - Pray Screen: 4.9★, 9.8K
  - Sanctify: 4.8★, 3.5K
  - FaithLocked: 4.8★, 915
  - Everything else has fewer than 400 ratings.
- **The former #1 is gone from the store.** "prayer lock: christian focus" (Covenant Studios: about 15K ratings, ~80K installs and ~$75K a month per screensdesign) returns a 404 on the US store. The Lookup API returns nothing for it in us/gb/ca/au/br/ae. "Pray Time - Bible Screen" (the "PrayTime" on our list) and "Bible Focus: Screen Time Lock" are gone too. The reason isn't public.
- **The #1 complaint, by far, is "paying to pray".** It covers a hard paywall with no close button right after onboarding, ads before a prayer, and trials that charge without warning. In the most recent reviews:
  - Pray Screen: 64 of 108 are 3★ or lower, mostly ads and price
  - Sanctify: 21 of 99
  - BibleScroll: 24 of 150
  - Bible Mode: 5 of 150. It keeps blocking free after the trial.

| App (developer) | ★ / ratings | Launched · last update | Lock | Unlock rule | What's free | Paid |
|---|---|---|---|---|---|---|
| Bible Mode (Friday Labs) | 4.9 / 12,880 | 2025-05 · 10-06 | ST (inferred) | Scan a physical open Bible **or** verse reflection + prayer + affirmation; opens for 15m/1h/2h/6h/all day | Blocking keeps working after the 3-day trial | "Supporter" $4.99–59.99 (10 tiers) |
| BibleScroll (Screen Detox) | 4.8 / 10,060 | 2026-02 · 11-15 | ST | Read today's passage for 1–15 min, then apps are open for the rest of the day | 7-day trial, then a hard paywall | $9.99/wk, $59.99/yr, "Annual Donation" tiers $25–199.99 |
| Pray Screen (Manifest Automation) | 4.9 / 9,772 | 2024-11 · 2025-09 | ST (inferred) | ~15-second prayer at set times (3×/day) | Ads: 2×30s per prayer | "Pro" $7.99–59.99 (10 tiers) |
| Sanctify (Sacred Studios) | 4.8 / 3,482 | 2025-10 · 10-08 | ST (inferred) | Daily prayer + Scripture goal | Paywall after personalisation, no exit | $3.99–5.99/wk, $29.99–49.99/yr |
| FaithLocked (V. González Martín) | 4.8 / 915 | 2026-05 · 10-22 | ST | Prayer pause, then a window; locks at 3 daily prayer times | 9 prayers, 3/day, Bible, community | $9.99/wk, $19.99–49.99/yr, $149.99 lifetime; **sells streak freezes** ($0.99) and coins |
| PrayLock (Ruvix) | 4.8 / 397 | 2025-03 · 11-04 | ST | Pray once a day, or per session | Hard paywall after setup | $4.99/wk, $9.99–39.99/yr |
| praise lock (You Can Just Do Things) | 4.8 / 281 | 2026-03 · 05-13 | ? | Say how you feel → AI scripture prayer → unlock | Hard paywall | 10 tiers, $7.99–79.99 |
| Holy Focus (Emin Karayel) | 4.8 / 157 | 2025-05 · 2025-10 | ST | Time slots or usage limits; blocking screen shows verse + prayer + icon, tap Amen | "Last offer" paywall loop | $8.99–77.90/yr (description and IAPs disagree) |
| Bible Focus - App Blocker (Daniel Ni) | 4.8 / 211 | 2026-03 · 07-17 | ? | Read a verse to unlock | Core free; a 2nd schedule costs | $29.99–59.99/yr |
| Scripture Before Scroll (James Liberty) | 4.8 / 56 | 2026-05 · 10-28 | ST | Daily reading; relocks every morning (lock time 0–5 AM) | **Everything, no IAP** | - |
| GirdUp (Tinsley George) | 5.0 / 35 | 2026-05 · 06-22 | ST | Morning lock until 15 min of Bible + prayer | **Locking is always free** | AI $9.99/mo, Academy $29.99/mo |
| GraceLock (T. Skulbru) | 5.0 / 2 | 2026-01 · 11-02 | ST | Read prompt → "I've Prayed" → 15+ min window | 3 apps, unlimited unlocks | $7.99/wk, $49.99/yr (7-day trial) |
| BlessUp (Relative Industries) | 4.2 / 18 | 2026-03 · 10-13 | ST | 2 mood check-ins → prayer → verse → apps open for the day | Nothing | $8.99, $59.99 |
| Pray App, ex "Prayer Lock: God First" (J. Kikani) | 4.8 / 55 | 2026-05 · 11-04 | ST | Prayer session at scheduled times (by tradition) | Has ads | $4.99/wk, $14.99/mo |
| Pray First, Scroll After (D. de Gregorio Neto) | - / 0 | 2026-06 · 06-26 | ? | Daily devotion | 3-day trial | $7.99/wk, $39.99/yr |
| AmenLock (Kyral Labs) | 5.0 / 2 | **2026-11-08** | ST | ~60s: verse → devotion → "Amen" → window | Plus required for blocking | $29.99–49.99/yr, freezes, coins |
| *Pray Time - Bible Screen* | *off the store* | 2025-05 | ? | Pause + verse + prayer; verse on every phone unlock | ? | ? |

## 1. Feature matrix

### 1a. Prayer-lock apps vs AmenKey v1 (SPEC)

| Feature | BMode | BScroll | PScreen | Sanct | FaithL | PrayLk | praise | HolyF | BFocus | SBS | GirdUp | GraceL | BlessUp | AmenLk | **AmenKey v1** |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Lock tech | ST | ST | ST | ST | ST | ST | ? | ST | ? | ST | ST | ST | ST | ST | **SC** |
| Per-open gate with a time window | Y | - | - | - | Y | $ | $ | Y | Y | - | - | Y | - | $ | **Y** |
| "Once a day" mode (pray once, open all day) | Y | $ | - | $ | - | $ | - | - | - | Y | Y | - | $ | - | **-** |
| Schedules / gate hours | ? | - | $ | - | Y | - | - | $ | $ | Y | Y | - | - | - | **-** |
| Minimum time before unlock (anti-skip) | - | $ | Y | ? | ? | ? | ? | ? | - | ? | Y | - | - | Y | **partial: 30s ring, but Amen isn't locked to it** |
| Mood-personalised prayer | - | - | - | $ | Y | $ | $ | - | - | - | - | $ | $ | - | **-** |
| AI-written prayers / chat | Y | - | - | $ | $ | - | $ | - | - | - | $ | - | - | - | **-** (good: no AI-theology risk) |
| Pray for a named person | - | - | - | - | - | $ | - | - | - | - | - | - | - | - | **Y** |
| Text them "I prayed for you" | - | - | - | - | - | - | - | - | - | - | - | - | - | - | **Y (unique)** |
| Prayer list + Answered wall | - | - | - | $ | - | $ | - | - | - | - | - | - | - | - | **Y** |
| Bible reader | Y | $ | - | $ | Y | $ | - | - | - | Y | Y | - | $ | $ | **- (verse only)** |
| Translations | KJV, ESV | BSB, WEB, KJV, ASV | - | multi | KJV, RV | full | - | - | - | BSB, WEB, KJV, ASV, NET | KJV, WEB, BSB | - | 1 | KJV, WEB, RV | **WEB** |
| Audio / read aloud | Y | - | - | - | - | - | - | - | - | Y | - | - | $ | - | **-** |
| Streak | Y | $ | $ | $ | Y | $ | $ | Y | ? | Y | Y | Y | $ | $ | **Y** |
| Streak freeze / grace | - | - | - | - | **sold** | - | - | - | - | pause | - | - | - | **sold** | **Y 1/wk free** |
| Badges / milestones | ? | - | - | $ | Y (43) | - | - | - | - | Y | - | - | $ | $ | **Y** |
| Pet / growing visual | - | - | - | - | sheep | - | - | - | - | - | - | - | - | dove | **-** |
| Journal | - | - | - | $ | Y | $ | - | - | - | notes | Y | $ | - | $ | **Y** |
| Widgets (home / lock) | Y | $ | - | Y | $ | - | - | - | - | Y | - | $ | $ | $ | **Y** |
| Community | - | - | - | chat | wall + live chat | 75-day group | - | - | - | family trivia | live Bible study $ | - | - | wall | **Circles** |
| Friends leaderboard | - | - | - | - | - | - | - | - | - | - | - | - | - | - | **Y (unique in lock apps)** |
| Challenges / plans | quiz | - | - | journeys $ | - | 75-Day $ | - | - | - | plans | courses $ | - | Bible-in-a-Year $ | - | **Y (4)** |
| Share cards | - | - | - | Y | - | $ | - | - | - | Y | - | - | - | - | **Y** |
| Emergency pass / pause | ? | Y | - | - | - | - | - | - | - | 1/3/7 days | manual | $ | - | $ | **1/day, 5 min** |
| Denomination / tradition | - | - | - | - | Y | - | - | - | - | - | - | - | - | Y | **-** |
| Ads | - | - | **Y** | - | - | - | - | - | - | - | - | - | - | - | **-** |
| Privacy label "Data Not Collected" | - | Y | - | - | ? | - | - | - | Y | - | ? | - | Y | - | **target Y** |

### 1b. Secular gates + faith leaders

| | one sec | ScreenZen | Opal | Hallow | Glorify | YouVersion |
|---|---|---|---|---|---|---|
| ★ / ratings | 4.8 / 24K | 4.9 / 54K | 4.7 / 92K (Editors' Choice) | 4.9 / 383K | 4.9 / ~101K | 4.9 / 14M |
| Core mechanic | Breathing pause, then "do you still want to open X?" with an attempt counter. Modes: Immediate / Delayed / Always Ask. | A wait timer that grows with each open, open-count limits, "is this important?" prompts | Focus sessions + time/open limits; Deep Focus can't be cancelled | Audio-guided prayer, 3 lengths, journal after | ~10-min devotional: quote → passage → devotional → meditation | Verse of the Day → Guided Scripture → Guided Prayer, plus plans |
| Shortcuts | **The gate itself:** App-open automation runs the "Activate one sec" intent. iOS 27: one-tap import. | A "shortcuts method" fallback, mentioned only in reviews | Only to start sessions | Siri Shortcuts | - | - |
| Screen Time | For re-intervention and hard blocks | Yes (main path) | Yes | - | - | - |
| Free | 1 app | **Everything (tips $5–40)** | 3 recurring sessions, unlimited on-demand, limits | A lot; Pray40/Pray25 paid | A little; audio paywalled | **Everything, no IAP** |
| Paid | $6.99/mo, $19.99/yr, $99.99 lifetime; Family $29.99/yr | - | $99.99/yr, weekly $4.99–9.99 | $69.99/yr; family $119.99 | $41.99–69.99/yr; $97 lifetime (web) | - |
| Onboarding | Screen-time assessment → add app → mode → Shortcuts setup → link Screen Time → paywall | Choose apps → limits → schedule. No account. | 21 screens: ATT → name → sign-up → quiz → "35 years" report → fist-bump commitment → soft paywall | Sign-up → name → interests → goals → paywall (✕ closes it) → ATT | ATT → sign-up → immediate soft paywall ("sponsorship") → notifications | Sign-in, no paywall |
| Streaks | - | Y | Score | 90%-finish = a day; **manual backfill** from the calendar; can hide | Tree of Faith; revisit missed days | Y + widget; no freeze; 7-day "mini celebrations" |
| Prayer list / requests | - | - | - | 240-char intentions; private / groups; "Pray for" + thank-you; notify a friend you prayed | Requests + gratitude | Private or friends-only cards; **Answered tab** |
| Community | - | Accountability-partner lock | - | Church + private groups, public campaigns | Groups, monthly evangelist leaderboard | Friends feed, Plans With Friends (up to 150) |
| Challenges | - | - | - | **Pray40 / Pray25** with celebrity hosts (~2M joined) | - | Global Bible Month (2.6M) |
| Top complaint | "Running your automation" banners, cumbersome setup, price, upsell instead of the breath | Unlock/pause bugs, easy to get around (picture-in-picture) | $99.99/yr; bypass by revoking Screen Time | Charged after the trial; "$70 money grab" | Unknowing annual charge, lost 217-day streak, audio paywalled | Streak resets during illness or grief, notification pile-up |
| Top love | "Made my unconscious habit conscious"; saying no is easy | Free, customizable, escalating waits | Polish, reports | Consistency, Fr. Mike, routines | Narration (not AI), design | Free, plans, prayer feature |

## 2. Table stakes (ship all of these or look like a toy)

- Pick apps, then a prayer or reading before they open, then a timed unlock window that relocks itself.
- Verse of the day, plus a home and lock-screen verse widget.
- A daily streak with a calendar, and a streak-at-risk evening reminder. GraceLock and YouVersion both do the reminder.
- An emergency or bypass option. Users who love these apps praise the escape hatch (BibleScroll "one-click disable", Scripture Before Scroll "pause 1/3/7 days").
- Daily reminder at a chosen time.
- An emotional onboarding with a "your screen time = N years" mirror. The former #1 used "16 years of your life", then a step-by-step permission tutorial.
- Basic stats: prayers, time saved, history.
- Dark mode, no account, offline content.

## 3. Differentiators worth stealing

| Idea | Best at it | How AmenKey should do it |
|---|---|---|
| Daily mode: one prayer unlocks everything until tomorrow | BibleScroll, Scripture Before Scroll, GirdUp | Add "Daily key" as an unlock style. Reset time is user-set (default 4 AM). Per-open stays the default for strict users. |
| Choose how long the prayer/reading takes (1–15 min) | BibleScroll (the most-praised feature in its 5★ reviews) | Guided length slider: 30s, 1, 2, 3, 5 min |
| Unlock by scanning a physical Bible | Bible Mode | v1.1 idea: camera + Vision text check for any Bible page. A novel "proof". |
| Pause for 1/3/7 days instead of uninstalling | Scripture Before Scroll | "Pause gate" for travel or sickness. Home shows "Paused until Thu". It counts honestly. |
| Streak backfill ("I prayed offline yesterday") | Hallow | Max 2 per month, plus the free weekly freeze |
| Streak that survives rest days | Pray First, Scroll After; Glorify's tree | An optional Sabbath rest day that doesn't break the streak |
| A growing visual instead of a bare number | FaithLocked (sheep), AmenLock (dove), Glorify (Tree of Faith), the ex-#1 (kingdom island) | A "key ring" or a doorway of light that gains a stone per gate honoured. No coins, no store. |
| "Pray for" notifications | Hallow, YouVersion | Ours goes further: the person gets a real iMessage. Add "Thank you" replies later via Circles. |
| Seasonal group challenge | Hallow Pray40 (~2M joined), YouVersion Global Bible Month (2.6M) | Run "Advent 25" now (Advent starts Nov 29) and "Lent 40" in Feb. Free, inside Circles. |
| Mood picker before the prayer | FaithLocked, GraceLock (10 moods), praise lock, BlessUp | One-tap chip row (Anxious, Grateful, Tempted, Tired, Lonely, Joyful) that picks prompts from a mood-tagged pool. Hand-written, not AI. |
| Trial-ending alert 2 days early | GraceLock | For v1.1 Pro. Kills the top billing complaint (Scroll The Bible, Bible Lock, Hallow). |
| Read aloud | Scripture Before Scroll (2 voices + highlight) | v1.1. Use the system's enhanced voices, default off. Pray App's TTS is called "creepy" in 2 of its 4 reviews. |
| Family trivia / game | Scripture Before Scroll, Bible Mode (trivia is the top-praised extra) | Later. Watch out: one Bible Mode user says games now replace Scripture. |
| Try a sample before setup or paywall | GraceLock: Christian Focus, PrayLock v1.10 | A 20-second "try the gate" demo in onboarding (see §7) |

## 4. Gaps nobody fills well (ranked)

1. **Free and trustworthy.** Most lock apps put a paywall straight after onboarding, many with no way to close it, and two add ads before prayer. "Free, no ads, no account, no tracking" is the strongest claim in this market, and only Scripture Before Scroll (56 ratings) makes it.
2. **Praying *for* people, outward.** None of the 17 apps has a person-first prayer loop. PrayLock's list is paid and private. The "Let Sarah know?" text is also free distribution.
3. **Friends accountability.** None of the lock apps has a friends leaderboard. Community there means anonymous prayer walls or live chat, which is a moderation burden.
4. **Reliability.** Screen Time apps get these 1★s: "locked out with no prayer to complete", "apps stayed locked after I prayed", "can't delete the app without a Screen Time passcode" (BibleScroll, Sanctify, Bible Lock, Pray Screen). A gate that never strands you beats a strict one that breaks.
5. **Fresh content.** Repetition is a top content complaint (Pray Screen "same prayer for weeks", Pray App "pages repeat", BibleScroll "repeats the same paragraphs"). At 5–15 gates a day, 25 prompts repeat within 2 days.
6. **Readability for older users.** BibleScroll gets "tiny light-gray text, can't enlarge" again and again.
7. **The temptation use case.** Many 5★s mention lust (Sanctify, FaithLocked, Pray Screen), and Unchaind has 48.8K ratings. Nobody offers a "Tempted? Pray now" one-tap path.
8. **Honest streaks.** Streak-loss bugs anger the most loyal users: Bible Mode's 501-day streak stopped counting, Glorify lost a 217-day streak, Bible Mode users lost days. Nobody sells "your streak is backed up".

## 5. Shortcuts-gate UX lessons (v1)

**Who to copy.** one sec is the only leader that still documents a Shortcuts gate. Its help center is the playbook. ScreenZen and Opal moved to Screen Time: ScreenZen's "shortcuts method" survives only as a reliability fallback in reviews, and Opal uses Shortcuts only to start sessions.

**How one sec explains setup** (https://tutorials.one-sec.app/en/articles/3034626)
- **iOS 17–26:** a 7-step text guide with one screenshot per step and an embedded video.
  1. Automation tab
  2. +
  3. App
  4. Pick the app, choose **Run Immediately**, tap Next
  5. Create New Shortcut
  6. Find "Activate one sec"
  7. **Re-select the app inside the action**: "Automation won't run without this ⚠️"
- **Legacy guide (iOS ≤16):** adds "turn off Ask Before Running. This step is very important." A separate post explains the **Notify When Run** toggle (iOS 15.4+).
- **iOS 27:** "Automations are now built directly into shortcuts, including shared shortcuts" (Apple). one sec 6.0 has an in-app "Add Intervention" button that imports the automation.
  - Imported automations arrive **disabled and greyed out** (MacStories), so one sec puts a ⚠️ on "Turn on the Automation".
  - If "Add Shortcut" fails, tap "Skip Setup" (an Apple bug).
- **Complaints anyway:** "Set up was little cumbersome." One automation per app, and users "can't duplicate or templatize automations."

**Failure points, ranked for AmenKey**

| # | Failure | What users see | AmenKey fix |
|---|---|---|---|
| 1 | Automation not enabled: "Ask Before Running" left on (≤iOS 16), or an iOS 27 import never switched on | Nothing happens; "it doesn't work" | Make the last guide step a full-screen illustration of the exact toggle. The verification below catches it. |
| 2 | App parameter left empty (one sec's step 7) | Gate never fires | **Ship one parameterless intent per supported app** ("Pray Before Instagram", "Pray Before TikTok"…). Keep the AppEntity version only for custom apps. That deletes the riskiest step. |
| 3 | Infinite loop | Gate → Continue → Instagram → gate again | Write the unlock window to the app group **before** opening the URL. The intent also honours a 30s "launch pass" per app, set by Continue and by the emergency pass. Copy in the guide: "Don't add an 'Open App' step. AmenKey reopens your app for you." |
| 4 | "Running your automation" banner on every open | Feels broken or spammy (one sec's top complaint) | Guide step: turn off **Notify When Run** |
| 5 | Glimpse: the target app flashes before the gate. Slow on iOS 18.0–18.2, improved in 18.3, fast again on 26. | "I can still see my feed" | The gate screen renders with no launch animation (budget ≤300 ms). Optional tip: replace the home-screen icon with a "Pray Before Instagram" shortcut icon so the app never shows. |
| 6 | iOS 26 full-screen screenshot editor backgrounds the app, so the gate re-fires | Gate fires after a screenshot | 20s grace: an app that reopens ≤20s after its window ended stays open |
| 7 | Restart: automations are dead for ~2 min | False "broken" reports | The troubleshooter says so |
| 8 | Focus filters or schedules suppress the automation | Gate skipped "randomly" | Troubleshooter item |
| 9 | The user deletes or turns off the automation | Bypass | Can't be prevented without Screen Time. Detect "no fires in 3 days while that app is gated" → a gentle "Is your gate still on? Run a test" card. Frame AmenKey as "a habit, not a cage". |
| 10 | App has no URL scheme | "Continue to app" can't open it | For custom apps, the Continue button says "Swipe back to your app". Or use a bridge shortcut: `shortcuts://run-shortcut?name=…` |
| 11 | Shortcuts app deleted | No action list | Detect with `canOpenURL("shortcuts://")` (add `shortcuts` to LSApplicationQueriesSchemes) and show an App Store "Get Shortcuts" banner, as one sec does |

**Prove it's set up.** Nobody has a test button. one sec only has a debug toggle that explains why the automation didn't run.
- **Per-app status** (from the per-app last-fired date the spec already stores):
  - Not set up
  - Waiting for first open
  - **Protected ✓ · last prayed-before 2h ago**
  - ⚠️ Silent for 3 days
- **"Test my gate" button per app:**
  1. Set `testPending[app]` in the app group, then open the app's URL scheme.
  2. The intent sees `testPending` and opens AmenKey to a "✓ Instagram is protected" screen instead of a prayer. Haptic plus confetti.
  3. If AmenKey comes back to the foreground with no fire within 8s, show the troubleshooter.
- **Troubleshooter, in this order:**
  1. Run Immediately on?
  2. Notify When Run off?
  3. The app chosen in the automation?
  4. Automation toggle on (iOS 27 import)?
  5. Restarted under 2 min ago?
  6. Focus mode on?
  7. Shortcuts installed?

**Setup flow to build**
- **iOS 27+:** one "Add to Shortcuts" button per app opens an iCloud shortcut link with the automation inside, then an illustrated "flip it on" step. Verify early in a spike that a shared shortcut can carry an App-trigger automation for a third-party app.
- **iOS 17–26:** the manual guide, with ≤6 steps because of the parameterless intents. Drawn mock screens, one step per screen, a big "Open Shortcuts" button, then "Test my gate".
- **Suggest starting with 1–3 apps.** Every app is another automation, and setup effort scales with it. Add an "Add another app" card on Home later.
- **Intent modes:** `supportedModes = [.background, .foreground(.dynamic)]` with `continueInForeground(alwaysConfirm: false)` on iOS 26+. `ForegroundContinuableIntent` (now deprecated) covers iOS 17–25. Silent return when unlocked.
- **Copy for the setup intro:** "Apple's Shortcuts app can ask AmenKey to step in when Instagram opens. It takes about a minute per app, and you only do it once."

## 6. Review-risk notes

- **4.3(b) spam / saturated category.** With 187 faith blockers launched in 2026, near-clone listings are everywhere:
  - AmenLock (launched 2026-11-08) copies FaithLocked's structure: the "never reads the content of your apps, only decides whether they're open or blocked" line, a companion pet, coins, paid streak freezes, a prayer wall.
  - Two different developers ship apps named "GraceLock".
  - Apple's text: "we will not accept new submissions unless they offer a meaningfully different or improved experience… may remove these apps… if they are not updated, improved, or do not attract customers." The ex-#1 and two others on our list are already off the store.
  - **Mitigation:**
    - Lead the listing and review notes with what nobody else has: pray for a named person and text them, Circles, the free Answered wall, no Screen Time needed.
    - Use original copy and screenshots, and never template text.
- **2.3.7 metadata.**
  - Pray Screen's subtitle reads "Opal, Hallow, Prayer, Glorify" (other apps' names). Don't name competitors in the subtitle or keywords.
  - "Pray First, Scroll After" is a live app name, and BlessUp uses "Pray First, Scroll Later". Our subtitle "Pray first. Scroll after." is legal but not distinctive; see §7.
- **2.3.1 misleading claims.** v1 doesn't use Screen Time and can't truly block. Don't put "blocker", "block apps" or "Screen Time" in v1 metadata. Say "gate", "pause" or "prayer before your apps open". Competitors that say "free" and then hard-paywall get "very misleading" reviews (praise lock, Bible Lock).
- **4.10: no monetising Screen Time APIs.** Apple: "You may not monetize… Apple services and technologies, such as… Screen Time APIs." BlessUp ("no features without a subscription") and AmenLock ("Plus required for app blocking") paywall the block itself. For v1.1 Strict Lock and Pro, keep blocking free forever and sell content and extras, the way GirdUp and Bible Focus do.
- **3.2.2(iv) donations.** BibleScroll sells "Annual Donation" subscriptions ($25–199.99). In-app charity fundraising isn't allowed for non-nonprofits, so never label a Pro tier a "donation".
- **1.2 user-generated content (Circles).** Display names plus a leaderboard count as UGC. Apple needs four things: a filter, report, block and published contact info.
  - **Plan:**
    - Name only, with a profanity filter. No free-text chat; encouragement already goes out through the share sheet.
    - Report member, block member, leave circle, hide-me-from-leaderboard.
    - Support email in the app.
    - "Delete my circle data", which also deletes the CloudKit public records.
  - AmenLock and FaithLocked declare "Contains User-Generated Content". AmenLock and YouVersion are rated 13+. Answer the age-rating questionnaire honestly.
- **2.1 completeness.** A "Coming soon" Strict Lock row is placeholder UI, so drop it from the v1 UI entirely. Reviewers must be able to see the gate work. Give them review notes with a 30-second screen recording of the Shortcuts setup and the gate firing, plus the demo launch argument path.
- **Privacy labels.** Many competitors declare tracking (identifiers): praise lock, PrayLock, GraceLock, Holy Focus, Sanctify, Pray Screen, AmenLock. If AmenKey ships no analytics SDK, it can claim "Data Not Collected" for everything except the Circles fields (name, weekly counts), so no ATT prompt. Keep it that way; it's a selling point.
- **Undeletable app.** In Screen Time apps, the "deny app removal" setting plus parental Screen Time traps users during the trial. In v1.1, never turn on removal protection by default. Make it an explicit opt-in with a warning.
- **Ads in the prayer flow.** Pray Screen shows an AI "sexy" ad right after prayer, which users report as offensive. Never.

## 7. Ranked changes to SPEC.md

1. **Store name: don't use "AmenKey: Pray to Unlock".** "AmenLock: Pray to Unlock" (Kyral Labs, id6815499649) went live 8 days ago, one word away. Use **`AmenKey: Pray Before Scrolling`** (30 chars) with the subtitle **`Say Amen to open your apps`** (26). No app is named AmenKey; full name check is in §8.
2. **Gate setup that verifies itself** (SPEC feature 2). This is where v1 lives or dies.
   - **(a)** Add one parameterless App Intent per preset app ("Pray Before Instagram"…). Keep `PrayFirstIntent(app:)` only for custom apps. That removes one sec's "re-select the app ⚠️" step.
   - **(b)** On iOS 27, an "Add to Shortcuts" button per app imports a shared shortcut with the automation inside, followed by an illustrated "turn it on" screen. Spike this first.
   - **(c)** The guide includes "Run Immediately" and "turn off Notify When Run" steps.
   - **(d)** Per-app status: Not set up / Waiting for first open / Protected ✓ (last fired) / ⚠️ Silent 3 days.
   - **(e)** A **"Test my gate"** button driven by a `testPending` flag, plus a 7-item troubleshooter (§5).
   - **(f)** Add `shortcuts` to LSApplicationQueriesSchemes, with a "Get Shortcuts" banner if it's missing.
3. **Loop-safe intent.**
   - Write the unlock window to the app group before calling `open(url)`.
   - Add a 30s per-app launch pass, set by Continue and by the emergency pass.
   - Add a 20s grace after a window ends, for the iOS 26 screenshot re-trigger.
   - `supportedModes = [.background, .foreground(.dynamic)]` on iOS 26+, and `ForegroundContinuableIntent` on 17–25.
   - Unit-test "Continue → reopen → silent".
4. **Make "Free. No ads. No account. No tracking." the promise.**
   - Put it on screenshot 1, in the description's first line and in the onboarding promise screen. ScreenZen proves a fully free gate can reach 4.9★ from 54K ratings.
   - Add to SPEC: v1.1 Pro never gates the prayer gate, Strict Lock blocking, streaks or Circles (Guideline 4.10). Its paywall needs a visible ✕ and a trial-ending reminder 2 days early, and only shows after the 3rd honoured gate, never in onboarding.
5. **Add the "Daily key" unlock style.**
   - Onboarding › Unlock style and Settings offer "Every time (window 5/15/30/60)" or "Once a day: your first prayer opens your apps until [4:00 AM]".
   - The intent checks `dailyKeyUntil` first.
   - This is the model behind the best-reviewed apps (BibleScroll, Scripture Before Scroll, GirdUp).
6. **Onboarding: teach the gate before Shortcuts.**
   - After "the promise", add a "Try it" screen: a fake Instagram icon. Tap it, the gate slides up, hold Amen for 1.2s, then confetti and "That's it. Now let's connect your real apps."
   - Suggest starting with 1–3 apps.
   - No gender question.
   - Keep it to ≤11 screens. The ex-#1 used 33.
7. **Honest anti-skip.**
   - The Amen button stays disabled (dimmed, labelled "Pray… 0:18") until the ring completes.
   - The timer pauses when the app leaves the foreground (`scenePhase`) and shows "Welcome back. Your prayer is waiting."
   - Guided length options: 30s, 1, 2, 3, 5 min.
   - Fixes "so easy to skip through" (Bible Mode) and "timer doesn't check I'm reading" (BibleScroll).
8. **Window-end nudge.** When an unlock starts, schedule a local notification for the window's end: "Your 15 minutes are up. Ready to put it down? 🙏" A Shortcuts gate can't kick you out, and this answers Pray Screen's "15-second prayer, then 3 hours of doomscrolling".
9. **Content volume and no repeats.**
   - prompts.json goes to ≥120 `quick` and ≥60 per ACTS key and `forSomeone`, plus a new `tempted` key (≥40).
   - Use a persisted shuffle bag per key in the app group: no repeat until the pool is exhausted.
   - The verse card rotates within the day: today's verse first, then a theme match.
10. **Streak integrity + grace.**
    - Compute the streak from the SwiftData session log, never from a stored counter.
    - Test DST, time zones and midnight.
    - Back up sessions and streak to iCloud (CloudKit private DB or KVS) so a reinstall keeps the streak. Show "Backed up to iCloud ✓".
    - Add Hallow-style "I prayed offline yesterday" (max 2 per month) and an optional rest day.
    - Copy: "Grace is free. We'll never sell streak freezes." FaithLocked and AmenLock sell them.
11. **Pause gate.** In Settings and on a Home long-press: 1 day, 3 days or 1 week. The status card reads "Paused until Thu 9:00 AM". It counts in stats. This is separate from the daily 5-minute emergency pass.
12. **A "Tempted? Pray now" path.** A widget button and a Home chip deep link to `amenkey://pray?mood=tempted`, which opens a 60s prayer from the `tempted` pool. No shame copy, and no gate needed.
13. **Mood chips at the start of every session.** One optional row: Anxious, Grateful, Tempted, Tired, Lonely, Joyful. They pick the prompt pool, and the last choice is remembered.
14. **"Pray for" loop upgrades.**
    - Make the "Let Sarah know?" text default-on and editable.
    - Count prayers for people toward Circles.
    - Marking a request Answered offers a share card ("God answered: [request]", with an optional verse). No lock app has this.
15. **Readability.** Add an in-session A−/A+ text size control on top of Dynamic Type. Verse text uses Cream on Midnight at ≥7:1. No body text below 4.5:1.
16. **Translations.** Ship KJV next to WEB (both public domain in the US), with a Settings toggle; verses.json stores both. Consider the BSB later. Users ask for NIV, ESV and NLT, but those are licensed, so add an FAQ line.
17. **Circles compliance (1.2).** Report, block, leave, hide-me-from-leaderboard, a name filter, a support email, and "Delete my circle data" that also removes the CloudKit public records. No free-text chat.
18. **Seasonal challenge.** Ship "Advent 25" in challenges.json (Nov 29–Dec 24) as a Circles-wide challenge. Plan "Lent 40" for Ash Wednesday, Feb 10, 2027.
19. **Remove the "Strict Lock: Coming soon" UI from v1** (2.1). Keep the code behind the flag.
20. **Copy rules.**
    - Never "blocker", "block" or "Screen Time" in v1 metadata (2.3.1).
    - No shame lines; a BibleScroll user quoted "don't come crying to me from hell".
    - No price next to "draw closer to God", which Sanctify reviewers called manipulative.
    - No competitor names in the subtitle or keywords (2.3.7).

## 8. Name check: AmenKey (US store, iTunes Search API + web, 2026-11-16)

- **No app is named "AmenKey".** "PrayPass" is taken twice: "PrayPass: App Blocker & Bible" (AIBL Softech, id6802146836) and "PrayPass: Christian Prayer" (id6815075449).
- **Closest collisions:**
  - **AmenLock: Pray to Unlock** (Kyral Labs, id6815499649, launched 2026-11-08, ST, $29.99–49.99/yr)
  - Prayer First: Amen to Unlock (Exposure Development, id6759683889)
  - Ameno - Pray Before You Unlock (id6762553318)
- **"Key" names:**
  - FaithKey: Bible App Blocker (id6815017080, 2026-09)
  - PrayKey: Prayer & App Blocker (ClearWhite, id6759605229)
  - Prayer Key - Put God First (id6759957259, 18 ratings)
  - BibleKey: Smart Bible App
  - VerseKey: Bible Memorization
- **"Amen" brands:**
  - **Amen: Catholic Bible & Prayers** (Augustine Institute, 45.3K ratings), the biggest "Amen" mark in the store
  - Amen: Christian Meditation (Amen.io, 6.9K)
  - Amen - Bible Chat (258)
  - Pray & Amen
  - prAmen — Prayer Circles
  - Amen: Prayer Tracker & Journal
  - Amen Clock
  - **Run a USPTO search for AMEN-formative marks in classes 9/41 before launch.**
- **"Pray to Unlock" titles:** AmenLock, Prayerful, Faith Reset, Prayblock. FaithLocked used it before renaming to "Bible App Blocker".
- **"Tap Amen to unlock" is not unique:** Holy Focus, Selah and Pause & Pray all do it. AmenKey's ownable moment is the **press-and-hold Amen with the haptic ramp + the key/doorway animation**, so make it visible in screenshot 1 and the preview video.

## Sources

- **App Store pages** (`https://apps.apple.com/us/app/id<ID>`):
  - Bible Mode 6744124873
  - BibleScroll 6755406222
  - Pray Screen 6737241669
  - Sanctify 6751909914
  - FaithLocked 6764309082
  - PrayLock 6741477596
  - praise lock 6759266143
  - Holy Focus 6744828672
  - Bible Focus 6758116005
  - Scripture Before Scroll 6771953135
  - GirdUp 6764598300
  - GraceLock 6758113098 / 6758605710
  - BlessUp 6759059549
  - Pray App 6761403250
  - Pray First, Scroll After 6781394750
  - AmenLock 6815499649
  - Bible Lock 6754575475
  - Scroll The Bible 6756558351
  - ex-#1 prayer lock 6744703926 (404)
  - Pray Time 6744620612 (no record)
- **Reviews:** `https://itunes.apple.com/us/rss/customerreviews/page=N/id=<ID>/sortby=mostrecent/json`
- **Ex-#1 teardown:** https://screensdesign.com/showcase/prayer-lock-christian-focus
- **Pray Time:** https://mwm.ai/apps/pray-time-bible-screen/6744620612
- **Apple guidelines** (4.3, 2.3.7, 3.2.2, 1.2, 4.10): https://developer.apple.com/app-store/review/guidelines/
- **Faith leaders:**
  - Hallow help (streaks, intentions, groups): https://help.hallow.com/en/articles/5761398-streaks-prayer-activity-faq and https://help.hallow.com/en/articles/10618520-how-to-pray-for-intentions-on-hallow
  - Pray40: https://hallow.com/pray40/
  - Glorify: https://screensdesign.com/showcase/glorify-devotional-prayer
  - YouVersion: https://apps.apple.com/us/app/bible/id282935706 and https://www.bible.com/prayer
- **Secular gates:**
  - one sec: https://apps.apple.com/us/app/id1532875441 · setup https://tutorials.one-sec.app/en/articles/3034626 · troubleshooting https://feedback.one-sec.app/help/collections/2767151-troubleshooting · loop https://feedback.one-sec.app/help/articles/3547019-stuck-in-an-endless-loop-ios · slow automations https://feedback.one-sec.app/help/articles/7569907-shortcut-automations-are-slow-ios · glimpse https://feedback.one-sec.app/help/articles/6900496-prevent-target-app-preview-avoid-the-glimpse-ios · notifications https://one-sec.app/blog/disable-shortcuts-automation-notifications/
  - ScreenZen: https://apps.apple.com/us/app/-/id1541027222
  - Opal: https://apps.apple.com/us/app/1497465230 · https://opalapp.com/help/5-ways-to-use-opal-with-shortcuts
  - iOS 27 Shortcuts: https://support.apple.com/en-us/149045 · https://www.macstories.net/stories/ios-and-ipados-27-review/13/
  - Loop-safe intent pattern: https://dev.to/eliguzz/building-an-open-source-one-sec-alternative-breaking-the-shortcuts-infinite-loop-thanks-to-ios-26-ka4
