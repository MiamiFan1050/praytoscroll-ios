import XCTest

/// Functional UI checks on the seeded demo (fast: -uitest shortens the prayer minimums).
final class FlowTests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func launch(_ extra: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-demo", "-uitest"] + extra
        app.launch()
        return app
    }

    /// A SwiftUI Toggle in a List reports the whole row; a tap on its middle can land on the label and do nothing.
    private func turnOn(_ toggle: XCUIElement) {
        guard (toggle.value as? String) != "1" else { return }
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
        if (toggle.value as? String) != "1", toggle.switches.firstMatch.exists { toggle.switches.firstMatch.tap() }
        XCTAssertEqual(toggle.value as? String, "1", "the switch is on")
    }

    private func sayAmen(in app: XCUIApplication) {
        let amen = app.descendants(matching: .any)["amenButton"]
        XCTAssertTrue(amen.waitForExistence(timeout: 10))
        expectation(for: NSPredicate(format: "value == ''"), evaluatedWith: amen)
        waitForExpectations(timeout: 10)
        amen.press(forDuration: 2.0)
    }

    func testQuickPrayerUnlocksAndCelebrates() {
        let app = launch([])
        let pray = app.buttons["home.prayNow"]
        XCTAssertTrue(pray.waitForExistence(timeout: 10))
        pray.tap()
        // Home's Pray now uses the person's style (guided in the demo): step through to the Amen.
        for _ in 0..<6 {
            if app.descendants(matching: .any)["amenButton"].exists { break }
            let next = app.buttons["session.next"]
            if next.waitForExistence(timeout: 3) { next.tap() }
        }
        sayAmen(in: app)
        XCTAssertTrue(app.descendants(matching: .any)["celebration.title"].waitForExistence(timeout: 10))
        let done = app.buttons["celebration.done"]
        XCTAssertTrue(done.waitForExistence(timeout: 5))
        done.tap()
        XCTAssertTrue(pray.waitForExistence(timeout: 10), "back home after the celebration")
    }

    func testAmenStaysLockedUntilTheMinimumTime() {
        let app = launch(["-route", "quick", "-longMinimum"])
        let amen = app.descendants(matching: .any)["amenButton"]
        XCTAssertTrue(amen.waitForExistence(timeout: 10))
        XCTAssertNotEqual(amen.value as? String ?? "", "", "Amen starts disabled")
        amen.press(forDuration: 1.5)
        XCTAssertFalse(app.descendants(matching: .any)["celebration.title"].exists)
    }

    func testOnboardingStartsAndAdvances() {
        let app = launch(["-onboarding"])
        let cta = app.buttons["onboarding.cta"]
        XCTAssertTrue(cta.waitForExistence(timeout: 10))
        XCTAssertTrue(app.descendants(matching: .any)["onboarding.headline"].exists)
        cta.tap()
        XCTAssertTrue(app.buttons["onboarding.back"].waitForExistence(timeout: 5), "moved past the welcome screen")
    }

    #if STRICT_LOCK   // the Screen Time lock (project-strictlock.yml)
    /// v1.1 Strict Lock: onboarding asks for Screen Time, shows the app picker (DemoLock stands in for Apple's in
    /// Debug), the picked apps' icons appear, the Shortcuts setup step is skipped and Home shows "Locked" with them.
    func testOnboardingPicksAppsToLockWithScreenTime() {
        let app = launch(["-onboarding", "-noMotion"])
        let cta = app.buttons["onboarding.cta"]
        let secondary = app.buttons["onboarding.secondary"]
        let headline = app.descendants(matching: .any)["onboarding.headline"].firstMatch
        XCTAssertTrue(cta.waitForExistence(timeout: 10))

        func step() {
            let opensSomething = ["prayer", "Show me how", "Start praying"].contains { cta.label.contains($0) }
            if cta.exists, cta.isEnabled, cta.isHittable, !(opensSomething && secondary.exists) {
                cta.tap()
            } else if secondary.exists, secondary.isHittable {
                secondary.tap()
            }
            Thread.sleep(forTimeInterval: 0.8)
            let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
            for label in ["Allow", "Don’t Allow", "Don't Allow"] where springboard.alerts.buttons[label].exists {
                springboard.alerts.buttons[label].tap()
                break
            }
        }

        // To "Which apps pull you in?"
        for _ in 0..<10 where !(headline.exists && headline.label.contains("Which apps")) { step() }
        XCTAssertTrue(headline.label.contains("Which apps"), "reached the app step")
        XCTAssertEqual(cta.label, "Choose apps")
        XCTAssertEqual(secondary.label, "Not now", "you can go on without locking anything yet")
        XCTAssertTrue(app.buttons["onboarding.useShortcuts"].exists, "the Shortcuts gate stays as the fallback")

        // Allow Screen Time → Apple's picker (the demo stand-in) → pick TikTok and Instagram.
        cta.tap()
        let done = app.buttons["lockpicker.done"]
        XCTAssertTrue(done.waitForExistence(timeout: 8), "the app picker opens")
        app.buttons["lockpicker.row.tiktok"].tap()
        app.buttons["lockpicker.row.instagram"].tap()
        done.tap()
        let icons = app.descendants(matching: .any)["lock.icons"].firstMatch
        XCTAssertTrue(icons.waitForExistence(timeout: 5), "the picked apps' icons show")
        XCTAssertTrue(icons.label.contains("TikTok") && icons.label.contains("Instagram"), icons.label)
        XCTAssertTrue(waitUntil(5) { cta.label == "Continue" })

        // Onward to Home: the Shortcuts setup page never appears.
        var sawShortcutsSetup = false
        for _ in 0..<12 where !app.buttons["home.prayNow"].exists {
            if headline.exists, headline.label.contains("Set up your Prayer Gate") { sawShortcutsSetup = true }
            if app.buttons["lockpicker.done"].exists { app.buttons["lockpicker.done"].tap() }
            step()
        }
        XCTAssertFalse(sawShortcutsSetup, "Screen Time needs no Shortcuts setup")
        XCTAssertTrue(app.buttons["home.prayNow"].waitForExistence(timeout: 8), "reached Home")
        let status = app.descendants(matching: .any)["home.gateStatus"].firstMatch
        XCTAssertTrue(status.waitForExistence(timeout: 5))
        let homeIcons = app.descendants(matching: .any)["lock.icons"].firstMatch
        XCTAssertTrue(homeIcons.waitForExistence(timeout: 5), "Home shows Locked: [the picked apps]")
        XCTAssertTrue(homeIcons.label.contains("TikTok"), homeIcons.label)
    }
    #endif

    #if STRICT_LOCK   // the Screen Time lock (project-strictlock.yml)
    /// Settings → Locked apps shows what's locked and the 15-minute note; the window choices start at 15.
    func testLockedAppsScreenShowsThePickedApps() {
        let app = launch(["-route", "lock"])
        XCTAssertTrue(app.descendants(matching: .any)["lock.title"].waitForExistence(timeout: 10))
        let icons = app.descendants(matching: .any)["lock.icons"].firstMatch
        XCTAssertTrue(icons.waitForExistence(timeout: 5))
        XCTAssertTrue(icons.label.contains("TikTok"), icons.label)
        XCTAssertTrue(app.buttons["lock.choose"].exists, "apps can be changed")
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS '15 minutes'")).firstMatch.exists,
                      "the 15-minute minimum is said in the UI")
    }
    #endif

    func testCircleLeaderboardShowsMeAndReportMenu() {
        let app = launch(["-route", "circle"])
        XCTAssertTrue(app.descendants(matching: .any)["circle.title"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.descendants(matching: .any)["circle.me"].firstMatch.waitForExistence(timeout: 5))
        let member = app.descendants(matching: .any)["circle.member"].firstMatch
        XCTAssertTrue(member.exists)
        member.press(forDuration: 1.0)
        XCTAssertTrue(app.buttons["Report"].waitForExistence(timeout: 5) || app.buttons["Report…"].exists,
                      "App Review 1.2: members can be reported")
    }

    func testAddAnotherAppBySearchShowsItInTheList() {
        // v1.1: the Shortcuts list is the fallback when Screen Time isn't allowed.
        let app = launch(["-route", "gate", "-shortcutsGate"])
        let edit = app.buttons["Edit"].firstMatch
        XCTAssertTrue(edit.waitForExistence(timeout: 10))
        edit.tap()
        let addAnother = app.buttons["apps.addAnother"]
        XCTAssertTrue(addAnother.waitForExistence(timeout: 10))
        addAnother.tap()
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("disc")
        let discord = app.buttons["addApp.discord"]
        XCTAssertTrue(discord.waitForExistence(timeout: 5))
        XCTAssertFalse(app.textFields.matching(NSPredicate(format: "placeholderValue CONTAINS 'scheme'")).firstMatch.exists,
                       "never asks for a URL scheme")
        discord.tap()
        let added = app.buttons["app.discord"]
        XCTAssertTrue(added.waitForExistence(timeout: 5), "Discord shows up in the list")
        XCTAssertTrue(added.isSelected, "and is gated")
    }

    func testUnlockForPickerThenAmenChoicesThenHomeShowsTheWindow() {
        let app = launch(["-route", "settings", "-shortcutsGate"])
        let unlockFor = app.buttons["settings.unlockFor"]
        for _ in 0..<6 where !unlockFor.isHittable { app.swipeUp() }
        XCTAssertTrue(unlockFor.waitForExistence(timeout: 10))
        unlockFor.tap()
        XCTAssertTrue(app.buttons["unlockFor.m5"].waitForExistence(timeout: 5), "5 min in Shortcuts mode")
        app.buttons["unlockFor.m45"].tap()
        XCTAssertTrue(app.buttons["unlockFor.m45"].isSelected)
        app.buttons["unlockFor.custom"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["unlock.customStepper"].waitForExistence(timeout: 3))
        app.buttons["unlockFor.m45"].tap()
        let ask = app.switches["unlock.askEachTime"]
        XCTAssertTrue(ask.waitForExistence(timeout: 3))
        for _ in 0..<3 where !ask.isHittable { app.swipeUp() }
        turnOn(ask)
        app.navigationBars.buttons.element(boundBy: 0).tap()   // back to Settings
        app.buttons["Done"].firstMatch.tap()

        let pray = app.buttons["home.prayNow"]
        XCTAssertTrue(pray.waitForExistence(timeout: 10))
        pray.tap()
        for _ in 0..<6 {
            if app.descendants(matching: .any)["amenButton"].exists { break }
            let next = app.buttons["session.next"]
            if next.waitForExistence(timeout: 3) { next.tap() }
        }
        sayAmen(in: app)
        let choices = app.descendants(matching: .any)["celebration.unlockChoices"]
        XCTAssertTrue(choices.waitForExistence(timeout: 10), "Ask me after each prayer shows the lengths")
        XCTAssertTrue(app.buttons["unlock.m45"].isSelected, "the default is preselected")
        app.buttons["unlock.m120"].tap()
        XCTAssertTrue(app.staticTexts["Unlocked for 2 h"].waitForExistence(timeout: 5))
        let done = app.buttons["celebration.done"]
        for _ in 0..<4 where !done.isHittable { app.swipeUp() }
        done.tap()
        let status = app.descendants(matching: .any)["home.gateStatus"]
        XCTAssertTrue(status.waitForExistence(timeout: 10))
        XCTAssertTrue(status.label.contains("1:59:") || status.label.contains("2:00:"), "Home counts down the 2 h picked: \(status.label)")
    }

    #if STRICT_LOCK   // the Screen Time lock (project-strictlock.yml)
    func testScreenTimeUnlockForStartsAtFifteenMinutes() {
        let app = launch(["-route", "settings"])   // the demo uses the Screen Time lock
        let unlockFor = app.buttons["settings.unlockFor"]
        for _ in 0..<6 where !unlockFor.isHittable { app.swipeUp() }
        XCTAssertTrue(unlockFor.waitForExistence(timeout: 10))
        unlockFor.tap()
        XCTAssertTrue(app.buttons["unlockFor.m15"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["unlockFor.m5"].exists, "5 min is Shortcuts only: Screen Time can't relock sooner than 15")
        XCTAssertTrue(app.buttons["unlockFor.rest"].exists)
    }
    #endif

    func testUnlockWithDevotionalShowsTheReadingThenAmen() {
        let app = launch(["-route", "settings"])
        let unlockWith = app.buttons["settings.unlockWith"]
        for _ in 0..<6 where !unlockWith.isHittable { app.swipeUp() }
        XCTAssertTrue(unlockWith.waitForExistence(timeout: 10))
        unlockWith.tap()
        XCTAssertTrue(app.buttons["unlockWith.prayer"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["unlockWith.prayer"].isSelected, "Prayer is the default")
        app.buttons["unlockWith.devotional"].tap()
        XCTAssertTrue(app.buttons["unlockWith.devotional"].isSelected)
        app.navigationBars.buttons.element(boundBy: 0).tap()   // back to Settings
        app.buttons["Done"].firstMatch.tap()

        let pray = app.buttons["home.prayNow"]
        XCTAssertTrue(pray.waitForExistence(timeout: 10))
        pray.tap()
        XCTAssertTrue(app.staticTexts["reading.title"].waitForExistence(timeout: 10), "a devotional, not a prayer prompt")
        XCTAssertTrue(app.staticTexts["reading.ref"].exists)
        XCTAssertTrue(app.staticTexts["reading.body"].exists)
        let prayer = app.staticTexts["reading.prayer"]
        for _ in 0..<4 where !prayer.isHittable { app.swipeUp() }
        XCTAssertTrue(prayer.label.hasSuffix("Amen."), "ends with its one-line prayer")
        sayAmen(in: app)
        XCTAssertTrue(app.descendants(matching: .any)["celebration.title"].waitForExistence(timeout: 10),
                      "a devotional completes like a prayer")
    }

    func testGateScreenLetsYouPickHowToUnlockWhenAskIsOn() {
        let app = launch(["-route", "gateask"])
        let devotional = app.buttons["session.method.devotional"]
        XCTAssertTrue(devotional.waitForExistence(timeout: 10), "Ask me after each prayer offers the method on the gate screen")
        XCTAssertTrue(app.buttons["session.method.prayer"].isSelected)
        devotional.tap()
        XCTAssertTrue(app.staticTexts["reading.title"].waitForExistence(timeout: 5))
        app.buttons["session.method.verse"].tap()
        XCTAssertTrue(app.staticTexts["reading.ref"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["reading.title"].exists, "a verse has no devotional title")
        XCTAssertTrue(app.buttons["session.method.verse"].isSelected)
        sayAmen(in: app)
        XCTAssertTrue(app.descendants(matching: .any)["celebration.unlockChoices"].waitForExistence(timeout: 10))
    }

    func testTheAllAppsAutomationOffersEveryAppAfterTheAmen() {
        let app = launch(["-route", "gateany", "-shortcutsGate"])
        sayAmen(in: app)
        XCTAssertTrue(app.buttons["celebration.backTo.instagram"].waitForExistence(timeout: 10),
                      "one automation can't say which app opened, so each gated app is offered")
        XCTAssertTrue(app.buttons["celebration.backTo.tiktok"].exists)
        XCTAssertTrue(app.buttons["celebration.done"].exists)
    }

    func testDeepLinkJoinOpensTogether() {
        let app = launch([])
        XCTAssertTrue(app.buttons["home.prayNow"].waitForExistence(timeout: 10))
        app.open(URL(string: "prayscroll://join?c=R4NB8T")!)
        XCTAssertTrue(app.descendants(matching: .any)["circle.title"].waitForExistence(timeout: 10)
                      || app.descendants(matching: .any)["circle.nickname"].waitForExistence(timeout: 5))
    }

    // MARK: Usernames + friends (v1.1)

    private func reveal(_ element: XCUIElement, in app: XCUIApplication, swipes: Int = 6) {
        for _ in 0..<swipes where !(element.exists && element.isHittable) { app.swipeUp() }
    }

    private func clearAndType(_ field: XCUIElement, _ text: String) {
        field.tap()
        let current = field.value as? String ?? ""
        if !current.isEmpty, current != "username" {
            field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count + 2))
        }
        field.typeText(text)
    }

    /// Settings → Username: reserved names are refused as you type, a taken name fails on save, a free one sticks
    /// (lowercased), and Settings shows it.
    func testPickAUsernameInSettings() {
        let app = launch(["-route", "settings", "-noUsername"])
        let row = app.buttons["settings.username"]   // under "You", at the top of Settings
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        reveal(row, in: app)
        XCTAssertTrue(row.label.contains("None"), row.label)
        row.tap()

        let field = app.textFields["username.field"]
        let save = app.buttons["username.save"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        clearAndType(field, "admin")
        XCTAssertTrue(app.descendants(matching: .any)["username.problem"].waitForExistence(timeout: 3), "reserved")
        XCTAssertFalse(save.isEnabled)

        clearAndType(field, "Grace")
        XCTAssertEqual(field.value as? String, "grace", "lowercased as you type")
        XCTAssertTrue(waitUntil(5) { save.isEnabled })
        save.tap()
        let error = app.descendants(matching: .any)["username.error"]
        XCTAssertTrue(error.waitForExistence(timeout: 5), "someone already has @grace")
        XCTAssertTrue(error.label.contains("taken"), error.label)

        clearAndType(field, "Faith_Walker")
        XCTAssertTrue(waitUntil(5) { save.isEnabled })
        save.tap()
        XCTAssertTrue(waitUntil(5) { !app.descendants(matching: .any)["username.error"].exists && !save.isEnabled },
                      "saved: nothing left to save")
        XCTAssertEqual(field.value as? String, "faith_walker")
        app.navigationBars.buttons.element(boundBy: 0).tap()   // back to Settings
        XCTAssertTrue(waitUntil(5) { row.label.contains("@faith_walker") }, row.label)
    }

    /// Together → Friends: find someone by their exact @username (no partial matches), send a request, accept one.
    func testAddAFriendByExactUsernameAndAcceptARequest() {
        let app = launch(["-route", "friends"])
        let add = app.buttons["friends.add"]
        XCTAssertTrue(add.waitForExistence(timeout: 10))
        XCTAssertTrue(app.descendants(matching: .any)["friends.myHandle"].exists)
        add.tap()

        let field = app.textFields["username.field"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        clearAndType(field, "hann")
        app.buttons["friends.search.find"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["friends.search.error"].waitForExistence(timeout: 5),
                      "no partial matches: there's no directory")

        clearAndType(field, "@Hannah_B")
        app.buttons["friends.search.find"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["friends.search.result"].waitForExistence(timeout: 5))
        let send = app.buttons["friends.search.send"]
        XCTAssertTrue(send.waitForExistence(timeout: 3))
        send.tap()
        XCTAssertTrue(app.descendants(matching: .any)["friends.search.requested"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["friends.search.block"].exists, "report + block on every username")
        // Return re-runs nothing and "Requested" stays (it used to flip back to "Send friend request").
        field.tap()
        field.typeText("\n")
        XCTAssertTrue(app.descendants(matching: .any)["friends.search.requested"].waitForExistence(timeout: 3))
        app.buttons["friends.search.done"].tap()   // not "Done": the keyboard's return key is called that too

        let cancel = app.buttons["friends.cancel.hannah_b"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 5), "the outgoing request shows with Cancel")

        let accept = app.buttons["friends.accept.jordan_k"]
        XCTAssertTrue(accept.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["friends.requestMenu.jordan_k"].exists, "report + block on every request")
        accept.tap()
        let jordan = app.descendants(matching: .any)["friends.row.jordan_k"].firstMatch
        reveal(jordan, in: app)
        XCTAssertTrue(jordan.waitForExistence(timeout: 5), "now a friend, with their streak")
        XCTAssertFalse(app.buttons["friends.accept.jordan_k"].exists)
    }

    /// "@grace prayed for you 🙏" shows in the app; "Pray for" a friend runs a prayer, and after the Amen it reads Prayed.
    func testPrayedForItemAndPrayingForAFriend() {
        let app = launch(["-route", "friends"])
        let item = app.descendants(matching: .any)["friends.prayedFor.grace"].firstMatch
        XCTAssertTrue(item.waitForExistence(timeout: 10))
        XCTAssertTrue(item.label.contains("@grace prayed for you"), item.label)
        XCTAssertTrue(app.descendants(matching: .any)["friends.row.me"].firstMatch.exists, "my streak sits with theirs")

        let prayFor = app.buttons["friends.prayFor.grace"]
        reveal(prayFor, in: app)
        XCTAssertTrue(prayFor.isEnabled)
        prayFor.tap()
        for _ in 0..<6 {
            if app.descendants(matching: .any)["amenButton"].exists { break }
            let next = app.buttons["session.next"]
            if next.waitForExistence(timeout: 3) { next.tap() }
        }
        sayAmen(in: app)
        XCTAssertTrue(app.descendants(matching: .any)["celebration.title"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.descendants(matching: .any)["letknow.title"].exists, "no text message to offer: they see it in the app")
        let done = app.buttons["celebration.done"]
        XCTAssertTrue(done.waitForExistence(timeout: 5))
        done.tap()
        XCTAssertTrue(prayFor.waitForExistence(timeout: 10))
        XCTAssertTrue(waitUntil(8) { !prayFor.isEnabled }, "Prayed today")
    }

    func testProfileLinkOpensAddFriend() {
        let app = launch([])
        XCTAssertTrue(app.buttons["home.prayNow"].waitForExistence(timeout: 10))
        app.open(URL(string: "prayscroll://u/hannah_b")!)
        XCTAssertTrue(app.descendants(matching: .any)["friends.search.result"].waitForExistence(timeout: 10),
                      "the link opens Add a friend with their username looked up")
    }

    #if STRICT_LOCK   // the Screen Time lock (project-strictlock.yml)
    /// Under Screen Time, "Not now" goes on without locked apps; Home then offers "Choose the apps to lock".
    func testOnboardingNotNowSkipsChoosingAppsAndHomeOffersItLater() {
        let app = launch(["-onboarding", "-noMotion"])
        let cta = app.buttons["onboarding.cta"]
        let secondary = app.buttons["onboarding.secondary"]
        let headline = app.descendants(matching: .any)["onboarding.headline"].firstMatch
        XCTAssertTrue(cta.waitForExistence(timeout: 10))
        func step() {
            let opensSomething = ["prayer", "Show me how", "Start praying", "Choose apps"].contains { cta.label.contains($0) }
            if cta.exists, cta.isEnabled, cta.isHittable, !(opensSomething && secondary.exists) {
                cta.tap()
            } else if secondary.exists, secondary.isHittable {
                secondary.tap()
            }
            Thread.sleep(forTimeInterval: 0.8)
            let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
            for label in ["Allow", "Don’t Allow", "Don't Allow"] where springboard.alerts.buttons[label].exists {
                springboard.alerts.buttons[label].tap()
                break
            }
        }
        for _ in 0..<10 where !(headline.exists && headline.label.contains("Which apps")) { step() }
        XCTAssertTrue(headline.label.contains("Which apps"), "reached the app step")
        XCTAssertTrue(cta.isEnabled, "Choose apps works before anything is picked")
        XCTAssertEqual(secondary.label, "Not now")
        secondary.tap()
        XCTAssertTrue(waitUntil(5) { !(headline.label.contains("Which apps")) }, "moved on without picking apps")
        for _ in 0..<14 where !app.buttons["home.prayNow"].exists { step() }
        XCTAssertTrue(app.buttons["home.prayNow"].waitForExistence(timeout: 8), "reached Home")
        let card = app.descendants(matching: .any)["home.gateStatus"].firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        XCTAssertTrue(card.staticTexts.matching(NSPredicate(format: "label == %@", "Choose the apps to lock")).firstMatch.exists,
                      "Home offers to choose them later")
    }
    #endif
}
