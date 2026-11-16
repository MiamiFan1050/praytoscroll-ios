# Pray to Scroll age rating: answers and reasoning

`AGE_RATING.json` has the same keys as the SplitSnap `rating.json` (fastlane `app_rating_config_path`).
**Expected result: 4+.** Definitions checked against Apple's
"Age ratings values and definitions" page on 2026-11-16.

| Question | Answer | Why |
|---|---|---|
| All violence, sexual, mature, horror, profanity, alcohol/drugs, weapons, simulated gambling | NONE | Prayer prompts, public-domain Bible verses and habit tools. Nothing in these categories. |
| Medical or Treatment Information | NONE | No diagnoses, medication or treatment guidance. The Terms say Pray to Scroll isn't medical advice. |
| **Contests** | **INFREQUENT** | Apple: "events that allow users to compete with one another for rankings, rewards, or the achievement of personal goals." Prayer Circles have a weekly leaderboard, and the solo challenges (40-day fast etc.) are personal goals. Both are secondary features with no prizes, so Infrequent, not Frequent. Infrequent stays 4+; Frequent would make the app 13+. |
| **Health or Wellness Topics** | **false** | Apple: "content that provides self-care or lifestyle recommendations" (examples: calorie tracking, dieting advice, exercise recommendations). Pray to Scroll is a prayer and focus app: prayer prompts, Bible verses and a habit gate, with no health, diet, fitness or medical guidance. Answering no keeps the app at **4+** (yes would make it 9+). Mark's call, 2026-11-16. Keep challenge tips spiritual or about phone habits, never health advice. |
| **User-Generated Content** | **true** | Apple's definition is "the broad distribution of content created by users." A circle nickname is only shown to people holding that circle's private code, so it isn't really broad. But it is text one user types and others see, App Review treats display names on a leaderboard as UGC under Guideline 1.2, and similar apps in this category declare it. Answering yes doesn't change the rating (it's a 4+ item). **It does mean the build needs the 1.2 safeguards:** a nickname filter, report member, block member, leave circle, and the published contact link (the support page's Contact us form). |
| Messaging and Chat | false | Users can't message each other inside Pray to Scroll. "Let them know" opens Apple's own Messages composer and the share sheet, so the user sends from Apple's app. If in-app encouragement through CloudKit is ever added, change this to true. |
| Social Media | false | No feed, no likes or comments, nothing spreads beyond a private circle. |
| Advertising | false | No ads. |
| Unrestricted Web Access | false | No in-app browser. Links to the privacy, terms and support pages are fixed URLs. |
| Parental Controls | false | Pray to Scroll is a self-control tool, not a parent-managed one. (Revisit if v1.1 Strict Lock adds guardian features.) |
| Age Assurance | false | No age verification or declared-age-range API. |
| Gambling, Loot Boxes | false | None. |

Note: Apple's API accepts both `INFREQUENT` (new scale) and `INFREQUENT_OR_MILD` (old scale) for `contests`.
If fastlane rejects `INFREQUENT`, use `INFREQUENT_OR_MILD`.
