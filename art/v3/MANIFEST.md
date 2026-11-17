# Pray to Scroll art v3 (11-17)

35 transparent 1024×1024 PNGs, one style: soft 3D, the house palette (midnight #0E1726, gold #E9B949 / #F5D58A / #B8862B, cream #FBF6EC, parchment #F3E9D6, sage #A8C3A0, rose #E7A6A1, ember #F08A4B) and the existing scroll mascot (`ref/` holds copies of `art/scroll_*.png`, used as the reference). No text is baked in, so titles stay in code and can be localized. Made with ChatGPT image generation via the Codex CLI; prompts are in `logs/`.

**No app code was changed.** Below is where each file is meant to go. Asset names are suggestions; `ArtImage(name:fallback:)` in `DesignSystem/Mascot.swift` already loads a catalog image and falls back to the current SF Symbol, so each swap is one line.

Checked against the top prayer/Bible app icons (iTunes Search, "prayer lock", "pray", "bible"): that category is padlocks, crosses and halos. Nothing in this set uses them.

## Badges: `WordBadge` (Features/Word/WordProgress.swift), 13

Frame: a scalloped gold seal around a navy enamel disc (it extends the drawn `BadgeView` look). Use them in the badge grid in `WordSheets.swift` (`ForEach(WordBadge.allCases)`) and on the badge milestone card in `FeedCards.swift` (`case .badge`). When a badge isn't earned yet, show it grayscale at about 35% opacity.

| File | Badge id | Title | Emblem |
|---|---|---|---|
| badge_firstSave.png | firstSave | First heart | rose heart |
| badge_firstGoal.png | firstGoal | Goal met | gold ring + check |
| badge_streak3.png | streak3 | 3 days running | small flame |
| badge_streak7.png | streak7 | A full week | flame + 7 stars |
| badge_streak30.png | streak30 | 30 days running | big flame + laurel |
| badge_read100.png | read100 | 100 verses | open book |
| badge_read500.png | read500 | 500 verses | stack of books |
| badge_read1000.png | read1000 | 1,000 verses | book on a stand with rays |
| badge_finish10.png | finish10 | Verse finisher | parchment + gold puzzle piece |
| badge_who10.png | who10 | Good listener | two speech bubbles |
| badge_allThemes.png | allThemes | Every theme | stained-glass rose window |
| badge_firstBoard.png | firstBoard | Collector | keepsake box of cards |
| badge_firstSend.png | firstSend | Encourager | parchment paper plane |

Asset catalog: `Badge-<id>` (e.g. `Badge-firstSave.imageset`). Optional: the streak milestones in `BadgeView` / `MilestoneEngine` (3, 7, 14, 21… days) can reuse badge_streak3/7/30.

## Levels: `WordLevel.names` (WordProgress.swift), 15

Frame: a cream-stone arched niche with a gold rim, the stage glowing inside. Use them on the level-up card (`WordEvent.levelUp` in FeedCards.swift), in the "Your reading" sheet, and optionally as a tiny icon in the feed's level chip ("Level 5 · Leaf").

| File | Level | Name | Starts at (verses) |
|---|---|---|---|
| level_01_seed.png | 1 | Seed | 0 |
| level_02_sprout.png | 2 | Sprout | 10 |
| level_03_root.png | 3 | Root | 30 |
| level_04_stem.png | 4 | Stem | 60 |
| level_05_leaf.png | 5 | Leaf | 100 |
| level_06_branch.png | 6 | Branch | 160 |
| level_07_bud.png | 7 | Bud | 250 |
| level_08_bloom.png | 8 | Bloom | 400 |
| level_09_fruit.png | 9 | Fruit (pomegranate) | 600 |
| level_10_vine.png | 10 | Vine (grapes) | 850 |
| level_11_orchard.png | 11 | Orchard | 1,200 |
| level_12_harvest.png | 12 | Harvest (wheat sheaf) | 1,700 |
| level_13_cedar.png | 13 | Cedar | 2,500 |
| level_14_oak.png | 14 | Oak | 3,500 |
| level_15_mountain.png | 15 | Mountain | 5,000 |

Asset catalog: `Level-01` … `Level-15` (look up by `WordLevel.number`).

## Onboarding heroes, 4 (Features/Onboarding/OnboardingView.swift)

| File | Shows | Suggested page |
|---|---|---|
| onb_1_pray_first.png | the scroll praying beside a phone behind a golden veil | `.promise` ("Here's the deal. When you open a gated app, you pray first.") |
| onb_2_pick_apps.png | the scroll placing plain app tiles into a gold arch | `.chooseApps` |
| onb_3_scroll_word.png | the scroll with a stream of verse cards and hearts | `.mirror`, or a "Scroll the Word" intro page |
| onb_4_pray_friends.png | the scroll praying, hearts flowing to three friend scrolls | `.username` ("friends add you by this name") |

The app tiles are plain colored squares, with no third-party logos. Asset catalog: `Onboarding-1` … `Onboarding-4`. Show them at about 240–280 pt.

## Empty states, 3

`EmptyState` (DesignSystem/Components.swift) always shows `MascotView(pose: .sleeping)` today. Give it an optional `artName` and pass these:

| File | Where |
|---|---|
| empty_saved.png | WordSheets.swift:45 "No saved verses yet" (also the empty board at :155) |
| empty_friends.png | TogetherView: the Friends section with no friends yet (next to "Invite from contacts") |
| empty_requests.png | CircleRequests.swift (a circle with no requests) and PeopleView.swift:77 "Who's on your heart?" |

Asset catalog: `Empty-saved`, `Empty-friends`, `Empty-requests`.

## Notes
- All files have real alpha (corners checked) and the whole subject fits inside the frame. Add them to the catalog as single-scale PNGs with "Preserve Vector Data" off. Xcode downsamples them. To save size, export @3x at the display size.
- Because these sit on midnight in dark mode and cream in light mode, test the levels' navy niche on cream. It reads fine, but don't put it on a navy card without a border.
- The App Store screenshots in `store/screenshots/v1.1/` use this set, so keep the two in sync.
