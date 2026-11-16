import XCTest

/// QA crawler. On every tab and demo route it taps every enabled, hittable button, cell, switch and menu item,
/// gets back to the screen after each tap, and checks the app is still running, isn't stuck and shows no error alert.
/// Each screen's log goes to $QA_DIR/crawl-NN-name.md (CI: out/qa) and to an attachment.
/// Destructive actions (erase, leave a circle, block) run in their own fresh-launch tests in DestructiveTests.
final class CrawlTests: XCTestCase {

    // MARK: Targets

    enum Cover {
        /// A tab's root (or a screen pushed inside a tab): on top when the tab bar is hittable.
        case tabBar
        /// A sheet with a navigation bar: on top when that bar is hittable.
        case navBar(String)
        /// Full-screen covers: on top when the marker itself is hittable.
        case marker
    }

    struct Target {
        let number: Int
        let name: String
        var args: [String] = []
        var tab: String?
        /// Taps from the launched screen to the screen under test (identifier, label, or "contains:<text>").
        var path: [String] = []
        /// Identifier or label of an element only this screen has.
        let marker: String
        var cover: Cover = .tabBar
        var scrolls = true
    }

    private func route(_ name: String) -> [String] { ["-route", name] }

    func test01Today() { crawl(Target(number: 1, name: "today", tab: "Today", marker: "home.prayNow")) }
    func test02Scroll() { crawl(Target(number: 2, name: "scroll-the-word", tab: "Scroll", marker: "word.feed", scrolls: false)) }
    func test03People() { crawl(Target(number: 3, name: "people", tab: "People", marker: "people.segment")) }
    func test04Together() { crawl(Target(number: 4, name: "together", tab: "Together", marker: "circles.create")) }
    func test05Progress() { crawl(Target(number: 5, name: "progress", tab: "Progress", marker: "stats.streak")) }
    func test06Answered() { crawl(Target(number: 6, name: "answered", args: route("answered"), marker: "answered.count")) }
    func test07Circle() { crawl(Target(number: 7, name: "circle", args: route("circle"), marker: "circle.title")) }
    func test08Journal() { crawl(Target(number: 8, name: "journal", args: route("journal"), marker: "journal.new")) }
    func test09Settings() {
        crawl(Target(number: 9, name: "settings", args: route("settings"), marker: "Settings", cover: .navBar("Settings")))
    }
    func test10GateSetup() {
        crawl(Target(number: 10, name: "gate-setup", args: route("gate"), marker: "gate.title", cover: .navBar("Prayer Gate")))
    }
    func test11GateVerified() {
        crawl(Target(number: 11, name: "gate-verified", args: route("verified"), marker: "verified.title", cover: .marker))
    }
    func test12Troubleshoot() {
        crawl(Target(number: 12, name: "troubleshoot", args: route("troubleshoot"), marker: "Troubleshoot", cover: .navBar("Troubleshoot")))
    }
    func test13GuidedPrayer() {
        crawl(Target(number: 13, name: "prayer-guided", args: route("pray"), marker: "session.styleLabel", cover: .marker, scrolls: false))
    }
    func test14GatePrayer() {
        crawl(Target(number: 14, name: "prayer-gate", args: route("gatepray"), marker: "session.styleLabel", cover: .marker, scrolls: false))
    }
    func test16PrayForSomeone() {
        crawl(Target(number: 16, name: "prayer-someone", args: route("someone"), marker: "session.styleLabel", cover: .marker, scrolls: false))
    }
    func test17ChoosePerson() {
        crawl(Target(number: 17, name: "choose-person", args: route("choose"), marker: "chooser.suggested", cover: .marker))
    }
    func test18AddPerson() {
        crawl(Target(number: 18, name: "add-person", tab: "People", path: ["people.add"], marker: "editor.name", cover: .navBar("Add someone")))
    }
    func test19PersonDetail() {
        crawl(Target(number: 19, name: "person-detail", tab: "People", path: ["contains:Dad"], marker: "person.pray"))
    }
    func test20NewCircle() {
        crawl(Target(number: 20, name: "new-circle", tab: "Together", path: ["circles.create"], marker: "circle.name", cover: .navBar("New circle")))
    }
    func test21JoinCircle() {
        crawl(Target(number: 21, name: "join-circle", tab: "Together", path: ["Join"], marker: "circle.code", cover: .navBar("Join a circle")))
    }
    func test22SavedVerses() {
        crawl(Target(number: 22, name: "saved-verses", tab: "Scroll", path: ["word.saved"], marker: "Saved verses", cover: .navBar("Saved verses")))
    }
    func test23GateGuide() {
        crawl(Target(number: 23, name: "gate-guide", args: route("gate"), path: ["gate.guide.instagram"], marker: "guide.next", cover: .marker, scrolls: false))
    }
    func test24EmergencyPass() {
        crawl(Target(number: 24, name: "emergency-pass", tab: "Today", path: ["I need it now"], marker: "emergency.use", cover: .marker, scrolls: false))
    }

    /// The real first run (what App Review sees on a fresh install): every page, every choice on it, then onward.
    func test25OnboardingWalk() {
        var log = CrawlLog(number: 25, name: "onboarding", args: ["-onboarding"])
        app = XCUIApplication()
        app.launchArguments = ["-demo", "-uitest", "-noMotion", "-onboarding", "-appearance", "dark"]
        app.launch()
        XCTAssertTrue(app.buttons["onboarding.cta"].waitForExistence(timeout: 10))
        let skipLabels: Set<String> = ["onboarding.cta", "onboarding.secondary", "onboarding.back"]
        var page = 0
        while page < 20, !app.buttons["home.prayNow"].exists {
            page += 1
            let headline = app.descendants(matching: .any)["onboarding.headline"].firstMatch
            let title = headline.exists ? headline.label : "page \(page)"
            log.section("Page \(page): \(title)")
            for control in snapshotControls().filter({ !skipLabels.contains($0.id) }).prefix(4) {
                guard let element = resolve(control), element.exists, element.isHittable else { continue }
                if control.type == .textField || control.type == .secureTextField { continue }
                let before = Set(snapshotControls().map(\.key))
                tapControl(control, element, log: &log)
                let outcome = observeOnboarding(before: before)
                log.row(control, outcome.text, failed: outcome.failed)
                if outcome.failed { break }
            }
            let cta = app.buttons["onboarding.cta"]
            let secondary = app.buttons["onboarding.secondary"]
            let opensSomething = ["prayer", "Show me how", "Start praying"].contains { cta.label.contains($0) }
            if cta.exists, cta.isEnabled, cta.isHittable, !(opensSomething && secondary.exists) {
                log.note("→ \(cta.label)")
                cta.tap()
            } else if secondary.exists, secondary.isHittable {
                log.note("→ \(secondary.label)")
                secondary.tap()
            } else {
                log.fail("stuck on “\(title)”: no enabled Continue or Skip")
                break
            }
            Thread.sleep(forTimeInterval: 1.0)
            _ = dismissSystemAlert(log: &log)
            if app.descendants(matching: .any)["gate.title"].exists {   // "Show me how" opened gate setup
                log.note("gate setup opened from onboarding; closing it")
                app.buttons["Done"].firstMatch.tap()
                Thread.sleep(forTimeInterval: 1.0)
            }
            if app.descendants(matching: .any)["amenButton"].exists {   // the first prayer started
                log.note("first prayer started; leaving it")
                restoreFromSession()
            }
        }
        if app.buttons["home.prayNow"].waitForExistence(timeout: 8) {
            log.note("Reached Home after \(page) pages.")
        } else {
            log.fail("onboarding never reached Home")
        }
        finish(log)
    }

    // MARK: Crawl

    private var app: XCUIApplication!
    static let tapsPerScreen = 14
    static let secondsPerScreen: TimeInterval = 40
    static let itemsPerMenu = 3

    override func setUp() {
        super.setUp()
        continueAfterFailure = true
        app = XCUIApplication()
    }

    private func crawl(_ target: Target) {
        var log = CrawlLog(number: target.number, name: target.name, args: target.args + (target.tab.map { ["tab:\($0)"] } ?? []) + target.path.map { "→ \($0)" })
        let started = Date()
        guard launch(target) else {
            log.fail("couldn't open the screen")
            finish(log)
            return
        }
        let discovered = discover(target)
        // Budget: unique controls first, repeats (list rows, cards) and plain cells last.
        let controls = discovered.enumerated().sorted { a, b in
            let ra = (a.element.index > 0 ? 2 : 0) + (a.element.type == .cell ? 1 : 0)
            let rb = (b.element.index > 0 ? 2 : 0) + (b.element.type == .cell ? 1 : 0)
            return ra != rb ? ra < rb : a.offset < b.offset
        }.map(\.element)
        log.note("Discovered \(controls.count) controls (budget: \(Self.tapsPerScreen) taps, \(Int(Self.secondsPerScreen)) s).")
        var known = Set(discovered.map(\.key))
        var untried: [Control] = []
        for control in controls {
            if log.tapped >= Self.tapsPerScreen || Date().timeIntervalSince(started) > Self.secondsPerScreen {
                untried.append(control)
                continue
            }
            guard restore(target, log: &log) else {
                log.fail("STUCK: couldn't get back to the screen after the previous tap")
                break
            }
            guard var element = resolve(control), element.exists else {
                log.row(control, "not on screen now (content changed)", skipped: true)
                continue
            }
            if !element.isHittable, target.scrolls { element = reveal(element, control) }
            guard element.isHittable else {
                log.row(control, "not hittable (off screen or covered)", skipped: true)
                continue
            }
            tapControl(control, element, log: &log)
            let outcome = observe(target, before: known)
            known.formUnion(outcome.seen)
            log.row(control, outcome.text, failed: outcome.failed)
            if outcome.items.isEmpty || outcome.failed { continue }
            // A menu, dialog or alert: try a few of its (non-destructive) items.
            for item in outcome.items.prefix(Self.itemsPerMenu) {
                guard restore(target, log: &log),
                      var parent = resolve(control), parent.exists else { break }
                if !parent.isHittable, target.scrolls { parent = reveal(parent, control) }
                guard parent.isHittable else { break }
                parent.tap()
                Thread.sleep(forTimeInterval: 0.8)
                guard let element = resolve(item), element.exists, element.isHittable else {
                    log.row(item, "↳ item didn't reappear", skipped: true, indent: true)
                    continue
                }
                log.tapped += 1
                element.tap()
                let result = observe(target, before: known)
                known.formUnion(result.seen)
                log.row(item, "↳ " + result.text, failed: result.failed, indent: true)
                dismissLeftovers()
            }
        }
        if !untried.isEmpty {
            log.note("Budget reached: \(untried.count) not tried: " + untried.prefix(20).map(\.display).joined(separator: ", ")
                     + (untried.count > 20 ? ", …" : ""))
        }
        log.note(String(format: "Finished in %.0f s.", Date().timeIntervalSince(started)))
        finish(log)
    }

    @discardableResult
    private func launch(_ target: Target) -> Bool {
        app.terminate()
        app = XCUIApplication()
        // -noMotion: the endless decorative animations pause (as with Reduce Motion), or an open menu makes every
        // later XCUITest action wait 60 s for "animations complete" (CI run 43941115392: 12 min on one screen).
        app.launchArguments = ["-demo", "-uitest", "-noMotion", "-appearance", "dark"] + target.args
        app.launch()
        if let tab = target.tab {
            let button = app.tabBars.buttons[tab]
            guard button.waitForExistence(timeout: 10) else { return false }
            button.tap()
        }
        if target.args.contains("-route") { Thread.sleep(forTimeInterval: 1.2) }
        for step in target.path {
            let element = pathElement(step)
            guard element.waitForExistence(timeout: 8) else { return false }
            if !element.isHittable { _ = reveal(element, nil) }
            element.tap()
            Thread.sleep(forTimeInterval: 1.0)
        }
        _ = app.descendants(matching: .any)[target.marker].firstMatch.waitForExistence(timeout: 10)
        return onScreen(target)
    }

    private func pathElement(_ step: String) -> XCUIElement {
        if step.hasPrefix("contains:") {
            let text = String(step.dropFirst("contains:".count))
            return app.buttons.matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
        }
        return app.descendants(matching: .any)[step].firstMatch
    }

    private func onScreen(_ target: Target) -> Bool {
        guard app.state == .runningForeground else { return false }
        let marker = app.descendants(matching: .any)[target.marker].firstMatch
        guard marker.exists else { return false }
        switch target.cover {
        case .tabBar: return app.tabBars.firstMatch.isHittable
        case .navBar(let title): return app.navigationBars[title].firstMatch.isHittable
        case .marker: return marker.isHittable
        }
    }

    /// Gets back to the target: dismiss whatever is on top, else relaunch along the path.
    private func restore(_ target: Target, log: inout CrawlLog) -> Bool {
        for _ in 0..<5 {
            let attempt = Date()
            if onScreen(target) { return true }
            if app.state == .notRunning { break }
            if app.state != .runningForeground {
                app.activate()
                _ = app.wait(for: .runningForeground, timeout: 6)
                continue
            }
            if dismissSystemAlert(log: &log) { continue }
            if !dismissOneLayer() { break }
            // A stalled app (XCUITest waiting out its 60 s animation timeout) won't get better: relaunch instead.
            if Date().timeIntervalSince(attempt) > 20 { break }
            Thread.sleep(forTimeInterval: 0.8)
        }
        if onScreen(target) { return true }
        log.relaunches += 1
        return launch(target)
    }

    /// Closes one alert, dialog, keyboard, sheet or pushed screen. Returns false when nothing could be closed.
    @discardableResult
    private func dismissOneLayer() -> Bool {
        let alert = app.alerts.firstMatch
        if alert.exists {
            for label in ["Cancel", "Not Now", "Not now", "OK", "Close"] where alert.buttons[label].exists {
                alert.buttons[label].tap()
                return true
            }
            let buttons = alert.buttons.allElementsBoundByIndex
            if let last = buttons.last { last.tap(); return true }
        }
        if app.keyboards.firstMatch.exists {
            for label in ["Return", "return", "Done", "done"] where app.keyboards.buttons[label].exists {
                app.keyboards.buttons[label].tap()
                return true
            }
        }
        // Closing a prayer asks first: leave it.
        let leave = app.buttons.matching(NSPredicate(format: "label == 'Leave prayer'")).firstMatch
        if leave.exists, leave.isHittable { leave.tap(); return true }
        // A pushed screen: go back (before any Done, which would close the whole sheet).
        for bar in app.navigationBars.allElementsBoundByIndex where bar.isHittable {
            let back = bar.buttons["BackButton"]
            if back.exists, back.isHittable { back.tap(); return true }
        }
        for label in ["Cancel", "Done", "Close", "Close prayer", "Not now", "Not Now", "Maybe later",
                      "Dismiss", "Skip", "Stay in Pray to Scroll"] {
            let button = app.buttons.matching(NSPredicate(format: "label == %@", label)).firstMatch
            if button.exists, button.isHittable { button.tap(); return true }
        }
        if app.sheets.firstMatch.exists || app.otherElements["PopoverDismissRegion"].exists {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.06)).tap()
            return true
        }
        // A sheet without buttons: drag it down.
        let window = app.windows.firstMatch.frame
        let start = app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: window.midX, dy: window.height * 0.18))
        let end = app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: window.midX, dy: window.height * 0.95))
        start.press(forDuration: 0.05, thenDragTo: end)
        return true
    }

    private func dismissLeftovers() {
        var scratch = CrawlLog(number: 0, name: "", args: [])
        _ = dismissSystemAlert(log: &scratch)
        if app.alerts.firstMatch.exists || app.sheets.firstMatch.exists { dismissOneLayer() }
    }

    private func restoreFromSession() {
        for _ in 0..<4 where app.descendants(matching: .any)["amenButton"].exists {
            let close = app.buttons["Close prayer"]
            if close.exists, close.isHittable { close.tap() } else { dismissOneLayer() }
            Thread.sleep(forTimeInterval: 0.8)
            let leave = app.buttons["Leave prayer"]
            if leave.exists, leave.isHittable { leave.tap() }
            Thread.sleep(forTimeInterval: 0.8)
        }
    }

    // MARK: Taps and outcomes

    private func tapControl(_ control: Control, _ element: XCUIElement, log: inout CrawlLog) {
        log.tapped += 1
        guard control.type == .switch else {
            element.tap()
            return
        }
        // Toggle it, check it flipped, and put it back.
        let before = element.value as? String
        element.tap()
        Thread.sleep(forTimeInterval: 0.6)
        if element.exists, element.value as? String == before {
            element.coordinate(withNormalizedOffset: CGVector(dx: 0.94, dy: 0.5)).tap()
            Thread.sleep(forTimeInterval: 0.6)
        }
        _ = dismissSystemAlert(log: &log)
        let after = element.exists ? element.value as? String : nil
        if after == before {
            log.note("switch “\(control.display)” didn't change (\(before ?? "?"))")
        } else if element.exists, element.isHittable {
            element.tap()
            Thread.sleep(forTimeInterval: 0.6)
            if element.exists, element.value as? String == after {
                element.coordinate(withNormalizedOffset: CGVector(dx: 0.94, dy: 0.5)).tap()
            }
            _ = dismissSystemAlert(log: &log)
        }
    }

    struct Outcome {
        var text: String
        var failed = false
        var items: [Control] = []
        var seen: Set<String> = []
    }

    private func observe(_ target: Target, before: Set<String>) -> Outcome {
        Thread.sleep(forTimeInterval: 0.7)
        switch app.state {
        case .notRunning:
            return Outcome(text: "**CRASH**: the app stopped running", failed: true)
        case .runningForeground:
            break
        default:
            return Outcome(text: "left the app (opened Shortcuts, Safari, Settings or another app)")
        }
        var scratch = CrawlLog(number: 0, name: "", args: [])
        if dismissSystemAlert(log: &scratch) {
            return Outcome(text: "system prompt: " + scratch.lastSystemPrompt)
        }
        let alert = app.alerts.firstMatch
        if alert.exists {
            let texts = alert.staticTexts.allElementsBoundByIndex.map(\.label).joined(separator: " · ")
            let buttons = alert.buttons.allElementsBoundByIndex.map(\.label)
            let failed = Self.looksLikeAnError(texts)
            return Outcome(text: (failed ? "**UNEXPECTED ALERT** " : "alert ") + "“\(texts)” [\(buttons.joined(separator: ", "))]",
                           failed: failed, items: alertItems(alert))
        }
        let dialog = app.sheets.firstMatch
        if dialog.exists {
            let texts = dialog.staticTexts.allElementsBoundByIndex.map(\.label).joined(separator: " · ")
            let buttons = dialog.buttons.allElementsBoundByIndex.map(\.label)
            return Outcome(text: "dialog “\(texts)” [\(buttons.joined(separator: ", "))]", items: alertItems(dialog))
        }
        if onScreen(target) {
            let after = snapshotControls()
            let seen = Set(after.map(\.key))
            let revealed = after.filter { !before.contains($0.key) && $0.isOnScreen }
            if revealed.isEmpty { return Outcome(text: "in place (no new controls)", seen: seen) }
            let labels = revealed.prefix(8).map(\.display).joined(separator: ", ")
            let items = revealed.filter { !Self.isDestructive($0.label) && !Self.isCancel($0.label) && $0.type != .switch }
            return Outcome(text: "revealed \(revealed.count): \(labels)", items: Array(items.prefix(8)), seen: seen)
        }
        return Outcome(text: "opened " + describeTopScreen())
    }

    private func observeOnboarding(before: Set<String>) -> Outcome {
        Thread.sleep(forTimeInterval: 0.8)
        if app.state == .notRunning { return Outcome(text: "**CRASH**", failed: true) }
        if app.state != .runningForeground {
            app.activate()
            return Outcome(text: "left the app")
        }
        var log = CrawlLog(number: 0, name: "", args: [])
        if dismissSystemAlert(log: &log) { return Outcome(text: "system prompt: " + log.lastSystemPrompt) }
        if app.alerts.firstMatch.exists {
            let texts = app.alerts.firstMatch.staticTexts.allElementsBoundByIndex.map(\.label).joined(separator: " · ")
            dismissOneLayer()
            return Outcome(text: "alert “\(texts)”", failed: Self.looksLikeAnError(texts))
        }
        if app.descendants(matching: .any)["amenButton"].exists {
            restoreFromSession()
            return Outcome(text: "started the sample prayer (left it)")
        }
        if !app.buttons["onboarding.cta"].exists {
            let top = describeTopScreen()
            dismissOneLayer()
            return Outcome(text: "opened \(top) (closed it)")
        }
        let changed = snapshotControls().filter { !before.contains($0.key) }.count
        return Outcome(text: changed > 0 ? "selected (page updated)" : "in place")
    }

    private func alertItems(_ container: XCUIElement) -> [Control] {
        var counts: [String: Int] = [:]
        return container.buttons.allElementsBoundByIndex.compactMap { button in
            let label = button.label
            let key = "L|\(label)"
            let index = counts[key, default: 0]
            counts[key] = index + 1
            guard !Self.isDestructive(label), !Self.isCancel(label) else { return nil }
            return Control(type: .button, id: button.identifier, label: label, index: index, frame: button.frame, isOnScreen: true)
        }
    }

    private func describeTopScreen() -> String {
        let bars = app.navigationBars.allElementsBoundByIndex.filter { $0.isHittable }.map(\.identifier).filter { !$0.isEmpty }
        if let title = bars.last { return "“\(title)”" }
        for id in ["amenButton", "celebration.title", "emergency.use", "chooser.suggested", "editor.name", "circle.name",
                   "verified.title", "guide.next", "letknow.title"] where app.descendants(matching: .any)[id].exists {
            return "[\(id)]"
        }
        if app.otherElements["ActivityListView"].exists || app.buttons["Copy"].exists { return "the share sheet" }
        let text = app.staticTexts.allElementsBoundByIndex.prefix(25).first(where: { $0.isHittable })?.label ?? "a new screen"
        return "“\(text.prefix(60))”"
    }

    @discardableResult
    private func dismissSystemAlert(log: inout CrawlLog) -> Bool {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let alert = springboard.alerts.firstMatch
        guard alert.exists else { return false }
        log.lastSystemPrompt = alert.label
        for label in ["Don’t Allow", "Don't Allow", "Not Now", "Cancel", "OK", "Allow"] where alert.buttons[label].exists {
            alert.buttons[label].tap()
            return true
        }
        alert.buttons.element(boundBy: 0).tap()
        return true
    }

    static func looksLikeAnError(_ text: String) -> Bool {
        let lower = text.lowercased()
        return ["error", "couldn", "could not", "failed", "went wrong", "unable", "try again", "not available"]
            .contains { lower.contains($0) }
    }

    static func isDestructive(_ label: String) -> Bool {
        let lower = label.lowercased()
        return ["erase", "delete", "leave circle", "remove", "stop", "block", "reset", "leave prayer"].contains { lower.contains($0) }
    }

    static func isCancel(_ label: String) -> Bool {
        ["cancel", "not now", "close", "done", "ok", "dismiss"].contains(label.lowercased())
    }

    // MARK: Discovery

    struct Control {
        let type: XCUIElement.ElementType
        let id: String
        let label: String
        let index: Int
        let frame: CGRect
        let isOnScreen: Bool

        var key: String { "\(type.rawValue)|\(id.isEmpty ? "L|" + label : "I|" + id)|\(index)" }
        var display: String {
            let kind: String
            switch type {
            case .switch: kind = "switch"
            case .cell: kind = "cell"
            case .link: kind = "link"
            case .textField: kind = "field"
            default: kind = "button"
            }
            let name = label.isEmpty ? id : label
            let shown = name.count > 48 ? String(name.prefix(48)) + "…" : name
            return "\(kind) “\(shown)”" + (id.isEmpty || id == label ? "" : " `\(id)`") + (index > 0 ? " #\(index + 1)" : "")
        }
    }

    private static let tappable: Set<XCUIElement.ElementType> = [.button, .switch, .link, .cell, .menuItem, .textField, .secureTextField]

    /// Every enabled control in the hierarchy (outside the tab bar, keyboard and status bar), in document order.
    /// Indices count every element with the same type + identifier/label, so `resolve` finds the same one.
    private func snapshotControls() -> [Control] {
        guard let root = try? app.snapshot() else { return [] }
        let screen = app.windows.firstMatch.frame
        var counts: [String: Int] = [:]
        var out: [Control] = []
        func hasTappableDescendant(_ node: XCUIElementSnapshot) -> Bool {
            node.children.contains { Self.tappable.contains($0.elementType) || hasTappableDescendant($0) }
        }
        func walk(_ node: XCUIElementSnapshot, excluded: Bool) {
            let type = node.elementType
            let skip = excluded || [.tabBar, .keyboard, .statusBar].contains(type)
            if Self.tappable.contains(type) {
                let sig = "\(type.rawValue)|\(node.identifier.isEmpty ? "L|" + node.label : "I|" + node.identifier)"
                let index = counts[sig, default: 0]
                counts[sig] = index + 1
                let frame = node.frame
                let usable = !skip && node.isEnabled && frame.width > 2 && frame.height > 2
                    && frame.maxX > 4 && frame.minX < screen.maxX - 4
                    && node.identifier != "BackButton"
                    && !(type == .cell && hasTappableDescendant(node))
                    && index < 2
                if usable {
                    out.append(Control(type: type, id: node.identifier, label: node.label, index: index, frame: frame,
                                       isOnScreen: frame.intersects(screen)))
                }
            }
            for child in node.children { walk(child, excluded: skip) }
        }
        walk(root, excluded: false)
        return out.filter { $0.type != .textField && $0.type != .secureTextField }
    }

    private func discover(_ target: Target) -> [Control] {
        var seen = Set<String>()
        var ordered: [Control] = []
        let pages = target.scrolls ? 3 : 1
        for page in 0..<pages {
            var added = 0
            for control in snapshotControls() where !seen.contains(control.key) {
                seen.insert(control.key)
                ordered.append(control)
                added += 1
            }
            if page > 0, added == 0 { break }
            if page < pages - 1, target.scrolls { scroll(up: true) }
        }
        if target.scrolls { launch(target) }   // back to the top without dragging a sheet closed
        return ordered
    }

    private func resolve(_ control: Control) -> XCUIElement? {
        let query = app.descendants(matching: control.type)
        let matches = control.id.isEmpty
            ? query.matching(NSPredicate(format: "identifier == '' AND label == %@", control.label))
            : query.matching(identifier: control.id)
        let element = matches.element(boundBy: control.index)
        return element
    }

    private func scroll(up: Bool) {
        let window = app.windows.firstMatch.frame
        let x = window.width * 0.09   // the left margin: away from buttons and the back-swipe edge
        // Downward drags are short so they never pull a sheet closed.
        let from = app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: x, dy: window.height * (up ? 0.72 : 0.40)))
        let to = app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: x, dy: window.height * (up ? 0.32 : 0.62)))
        from.press(forDuration: 0.05, thenDragTo: to, withVelocity: .default, thenHoldForDuration: 0.1)
        Thread.sleep(forTimeInterval: 0.4)
    }

    /// Scrolls until the element can be tapped (toward it first, then back the other way).
    private func reveal(_ element: XCUIElement, _ control: Control?) -> XCUIElement {
        let window = app.windows.firstMatch.frame
        let below = element.exists ? element.frame.midY > window.midY * 0.8 : true
        for _ in 0..<4 {
            if element.exists, element.isHittable { return element }
            scroll(up: below)
            if let control, let again = resolve(control), again.exists, again.isHittable { return again }
        }
        return element
    }

    // MARK: Log

    struct CrawlLog {
        let number: Int
        let name: String
        let args: [String]
        var lines: [String] = []
        var rows = 0
        var tapped = 0
        var skipped = 0
        var problems: [String] = []
        var relaunches = 0
        var lastSystemPrompt = ""

        mutating func section(_ title: String) {
            lines.append("")
            lines.append("**\(title)**")
            lines.append("")
            lines.append("| # | control | result |")
            lines.append("|---|---|---|")
        }

        mutating func row(_ control: Control, _ result: String, failed: Bool = false, skipped: Bool = false, indent: Bool = false) {
            if rows == 0 && !lines.contains(where: { $0.hasPrefix("| # |") }) {
                lines.append("")
                lines.append("| # | control | result |")
                lines.append("|---|---|---|")
            }
            rows += 1
            if skipped { self.skipped += 1 }
            let cell = result.replacingOccurrences(of: "|", with: "/").replacingOccurrences(of: "\n", with: " ")
            lines.append("| \(indent ? "" : String(rows)) | \(indent ? "&nbsp;&nbsp;" : "")\(control.display) | \(cell) |")
            if failed { problems.append("\(control.display): \(result)") }
        }

        mutating func note(_ text: String) { lines.append("") ; lines.append(text) }

        mutating func fail(_ text: String) {
            problems.append(text)
            lines.append("")
            lines.append("**FAIL**: \(text)")
        }

        var markdown: String {
            let header = "## \(String(format: "%02d", number)) \(name)" + (args.isEmpty ? "" : "  `\(args.joined(separator: " "))`")
            let summary = "Tapped \(tapped) · skipped \(skipped) · relaunches \(relaunches) · problems \(problems.count)"
            let problemList = problems.isEmpty ? "" : "\n\nProblems:\n" + problems.map { "- \($0)" }.joined(separator: "\n")
            return header + "\n\n" + summary + problemList + "\n" + lines.joined(separator: "\n") + "\n"
        }
    }

    private func finish(_ log: CrawlLog) {
        let text = log.markdown
        let attachment = XCTAttachment(string: text)
        attachment.name = String(format: "crawl-%02d-%@", log.number, log.name)
        attachment.lifetime = .keepAlways
        add(attachment)
        if let dir = ProcessInfo.processInfo.environment["QA_DIR"], !dir.isEmpty {
            let url = URL(fileURLWithPath: dir).appendingPathComponent(String(format: "crawl-%02d-%@.md", log.number, log.name))
            try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? text.write(to: url, atomically: true, encoding: .utf8)
        }
        for problem in log.problems { XCTFail("[\(log.name)] \(problem)") }
    }
}
