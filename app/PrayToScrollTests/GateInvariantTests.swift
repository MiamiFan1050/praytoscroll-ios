import XCTest
@testable import PrayToScroll

/// Properties the gate must keep whatever state it's in: nothing opens forever, and every open has an end.
final class GateInvariantTests: XCTestCase {
    private let now = TestCalendar.date(2026, 11, 16, 9)

    func testNoStateKeepsAGatedAppOpenForever() throws {
        var rng = SplitMix64(seed: 2026)
        func maybe() -> Date? {
            Bool.random(using: &rng) ? now.addingTimeInterval(Double.random(in: -7_200...86_400 * 8, using: &rng)) : nil
        }
        for _ in 0..<3_000 {
            let snapshot = GateSnapshot(gateEnabled: true, gatedAppIDs: ["instagram", "tiktok"], customApps: [],
                                        unlockedUntil: maybe(), pausedUntil: maybe(), dailyKeyUntil: maybe(),
                                        launchPasses: ["instagram": maybe()].compactMapValues { $0 },
                                        testPending: ["instagram": maybe()].compactMapValues { $0 })
            let ends = [snapshot.unlockedUntil, snapshot.pausedUntil, snapshot.dailyKeyUntil,
                        snapshot.launchPasses["instagram"], snapshot.testPending["instagram"]].compactMap { $0 }
            let horizon = max(ends.max() ?? now, now)
            let later = horizon.addingTimeInterval(GateEngine.graceSeconds + GateEngine.testWindowSeconds + 1)
            for app in ["instagram", "tiktok"] {
                XCTAssertEqual(GateEngine.decide(appID: app, now: later, snapshot: snapshot), .requirePrayer,
                               "\(app) must ask for a prayer again once every pass has ended: \(snapshot)")
                if case .allow(let until, let reason) = GateEngine.decide(appID: app, now: now, snapshot: snapshot) {
                    XCTAssertFalse([AllowReason.gateOff, .notGated].contains(reason))
                    let end = try XCTUnwrap(until, "a gated app is only ever let through until a known time (\(reason))")
                    XCTAssertGreaterThan(end, now)
                }
            }
        }
    }

    func testGraceIsExactlyTwentySecondsAfterTheWindow() {
        let end = now.addingTimeInterval(15 * 60)
        let snapshot = GateSnapshot(gateEnabled: true, gatedAppIDs: ["instagram"], customApps: [],
                                    unlockedUntil: end, pausedUntil: nil, dailyKeyUntil: nil)
        XCTAssertEqual(GateEngine.decide(appID: "instagram", now: end.addingTimeInterval(-0.5), snapshot: snapshot),
                       .allow(until: end, reason: .unlocked))
        XCTAssertEqual(GateEngine.decide(appID: "instagram", now: end, snapshot: snapshot),
                       .allow(until: end.addingTimeInterval(20), reason: .grace))
        XCTAssertEqual(GateEngine.decide(appID: "instagram", now: end.addingTimeInterval(19.9), snapshot: snapshot),
                       .allow(until: end.addingTimeInterval(20), reason: .grace))
        XCTAssertEqual(GateEngine.decide(appID: "instagram", now: end.addingTimeInterval(20), snapshot: snapshot), .requirePrayer)
    }

    func testStackedPrayersNeverMakeAWindowLongerThanOneChoiceFromNow() {
        var until: Date?
        var clock = now
        for _ in 0..<50 {   // pray again and again, a minute apart
            until = GateEngine.unlock(from: clock, minutes: 60, existing: until)
            XCTAssertLessThanOrEqual(until!.timeIntervalSince(clock), 60 * 60 + 0.001)
            clock = clock.addingTimeInterval(60)
        }
    }
}

/// Scroll the Word's feed is built from every verse in the bundle.
final class WordFeedTests: XCTestCase {
    func testFeedHoldsAll366VersesOnceFromAnyStartDay() throws {
        let url = try XCTUnwrap(Bundle(for: AppModel.self).url(forResource: "verses", withExtension: "json"))
        let verses = try JSONDecoder().decode([Verse].self, from: Data(contentsOf: url))
        XCTAssertEqual(verses.count, 366, "a verse for every day, leap day included")
        let prompts = ["Thank God for one thing.", "Pray for {name}.", "Ask for patience today."]
        for start in [1, 59, 60, 200, 365, 366] {
            let ordered = WordFeedPlanner.order(verses: verses, topic: nil, seen: [], today: start, seed: UInt64(start))
            let items = FeedItem.build(ordered: ordered, prompts: prompts, promptOffset: start)
            let shown = items.compactMap(\.verse)
            XCTAssertEqual(shown.count, 366)
            XCTAssertEqual(Set(shown.map(\.day)).count, 366, "every day once (start \(start))")
            XCTAssertEqual(shown.first?.day, start, "the feed opens on today's verse")
            XCTAssertEqual(Set(items.map(\.id)).count, items.count, "ids are unique, so paging can't jump")
            let promptCards = items.compactMap(\.prompt)
            XCTAssertEqual(promptCards.count, 366 / 5, "a prayer prompt after every 5 verses")
            XCTAssertFalse(promptCards.contains { $0.contains("{name}") }, "no unfilled name placeholders")
        }
    }
}
