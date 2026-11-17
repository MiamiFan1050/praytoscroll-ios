# Pray to Scroll: App Store Connect "App Privacy" answers

Fill this in under App Store Connect → Pray to Scroll → App Privacy. It matches the privacy policy
(https://praytoscroll.vercel.app/privacy.html) and assumes the v1.0 build has **no third-party SDKs** (no analytics,
ads, crash reporting or attribution). If any SDK is added, redo this page.

**Privacy Policy URL:** `https://praytoscroll.vercel.app/privacy.html`
**Privacy Choices URL:** leave blank.

## Step 1: "Do you or your third-party partners collect data from this app?"

**Yes.** The only reason is Prayer Circles. Circle records live in Pray to Scroll's **CloudKit public database**
(`iCloud.com.amenkeyapp.ios`), which the developer can read in the CloudKit Console. Under Apple's
definition ("transmitting data off the device in a way that allows you … to access it for a period longer
than necessary to service the transmitted request in real time"), that counts as collected.
Everything else stays on the device and is **not** "collected" (see the table at the end).

## Step 2: Data types (tick exactly these two)

| Category | Data type | Tick? | What it is in Pray to Scroll |
|---|---|---|---|
| Contact Info | Name, Email Address, Phone Number, Physical Address, Other User Contact Info | No | The first name used for the greeting stays on the device. The user's own email or phone is never asked for. A phone number saved for someone on the prayer list (for "Let them know" texts) stays on the device. |
| Health & Fitness | Health, Fitness | No | |
| Financial Info | Payment Info, Credit Info, Other Financial Info | No | No purchases in v1. |
| Location | Precise, Coarse | No | |
| Sensitive Info | Sensitive Info | No (see note) | |
| Contacts | Contacts | No | 1.0.1: with the user's permission (optional), "Add someone" searches the address book by name on the device. Contacts are read into memory only while that screen is open and are never uploaded, synced or stored in bulk; only the person picked is saved (name + one phone number) in the on-device prayer list. Without permission (or with iOS 18 limited access) Apple's picker / the shared subset is used. v1.1 adds Friends → "Invite from contacts": the same on-device search, then Apple's Messages sheet for one person with the user's /u/<handle> link; the user taps Send, no bulk or automatic sends, nothing about the contact is stored or uploaded. Apple's definition of "collect" is transmitting off the device, so this stays **No**: no label change. |
| User Content | Emails or Text Messages, Photos or Videos, Audio Data, Gameplay Content, Customer Support, Other User Content | No | The journal and prayer list stay on the device. Messages are sent from Apple's Messages sheet. The support form is on the website, outside the app. |
| Browsing History | Browsing History | No | |
| Search History | Search History | No | Journal search runs on the device. |
| **Identifiers** | **User ID** | **Yes** | The circle **nickname** (a screen name), the optional **@username** (v1.1, friends) and the anonymous CloudKit user record ID that Apple attaches to each record. The **circle code** is stored with them. |
| Identifiers | Device ID | No | No IDFA or IDFV is used. |
| Purchases | Purchase History | No | |
| **Usage Data** | **Product Interaction** | **Yes** | The **weekly prayer count** and **current streak** shown on the circle leaderboard and (v1.1) next to friends; v1.1 "prayed for you" rows (who prayed for whom, and on which day). |
| Usage Data | Advertising Data, Other Usage Data | No | |
| Diagnostics | Crash Data, Performance Data, Other Diagnostic Data | No | There's no crash or analytics SDK. Crash reports that users choose to share with developers come through Apple, and Apple collects those. |
| Surroundings / Body | Environment Scanning, Hands, Head | No | |
| Other Data | Other Data Types | No | |

**Sensitive Info note.** The category covers "religious or philosophical beliefs". We don't tick it: Pray to Scroll
collects no statement of belief, denomination or affiliation. It collects a session count and a streak
(Product Interaction) under a nickname the user picks. If Mark wants the most cautious label anyway,
tick Sensitive Info with the same answers as below (App Functionality, linked, not tracking).

## Step 3: For each ticked type

### Identifiers → User ID
- **Purposes:** App Functionality **only**. Do not tick Third-Party Advertising, Developer's Advertising or Marketing, Analytics, Product Personalization or Other Purposes.
- **Is it linked to the user's identity?** **Yes.** The record is tied to the user's iCloud account through CloudKit's user record ID, and the nickname is shown to other members.
- **Is it used for tracking?** **No.**

### Usage Data → Product Interaction
- **Purposes:** App Functionality **only**.
- **Linked to the user's identity?** **Yes.** It's stored in the same circle record as the User ID.
- **Used for tracking?** **No.**

## Expected label on the App Store

- **Data Used to Track You:** none.
- **Data Linked to You:** Identifiers, Usage Data.
- **Data Not Linked to You:** none.

(A user who never joins a circle and never picks a username sends nothing. The label still lists these types because the app can collect them.)

**v1.1 friends:** usernames, friend requests/links, "prayed for you" rows and blocks live in the same CloudKit public
database. They fall under the types already ticked (User ID, Product Interaction, and Other User Content for circle
prayer requests): no new data type. There are no messages between friends.

## Not collected: stays on the device

| Data | Where it lives |
|---|---|
| Gate state: gated apps, unlock window, unlock end time, last-fired dates, emergency pass | App Group UserDefaults (`group.com.amenkeyapp.ios`), shared with the widget and Shortcuts actions |
| Prayer list: people, relationships, requests, answered prayers | SwiftData on the device |
| Journal, sessions, streak history, challenges, settings, first name | SwiftData / App Group on the device |
| People added from Contacts: name + one phone number for texting | SwiftData on the device (the address book itself is never copied) |
| Scroll the Word: verses read or swiped | Bundled World English Bible; nothing is fetched or sent |
| Reminders | Local notifications only, no push server |
| Device backups | Apple's iCloud or computer backups, under Apple's policy. We can't access them. |

**Identifiers:** the CloudKit container and App Group keep the registered `com.amenkeyapp.ios` IDs after the rename. If they change, update them here and in site/privacy.html.

**Contacts permission (1.0.1):** `NSContactsUsageDescription` = "Find the people you pray for by name, and text them that you prayed. Your contacts never leave your iPhone." Asked the first time someone opens Add someone / Pray for someone with an empty list; declining leaves the picker and typed names. "Let them know" opens Apple's Messages sheet with the number and text filled in; the user taps Send, nothing is sent automatically.

**Tracking / ATT:** Pray to Scroll doesn't track, so there's no App Tracking Transparency prompt and no
`NSUserTrackingUsageDescription`.

**Privacy manifest (`PrivacyInfo.xcprivacy`) should match this page:**
- `NSPrivacyTracking` = false, with no tracking domains.
- `NSPrivacyCollectedDataTypes`: User ID and Product Interaction, each with Linked = true, Tracking = false and purpose App Functionality.
- `NSPrivacyAccessedAPITypes`: UserDefaults with reasons `CA92.1` (the app's own defaults) and `1C8F.1` (the App Group), plus any other required-reason API the build uses.
