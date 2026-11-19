import XCTest
@testable import PrayToScroll

/// Night prayer (the evening Examen): five steps, enough original lines that a nightly habit doesn't repeat for weeks.
final class NightPrayerTests: XCTestCase {
    func testFiveStepsInOrder() {
        XCTAssertEqual(ExamenStep.allCases.map(\.title), ["Thank", "Look back", "Sorry", "Ask", "Tomorrow"])
        XCTAssertEqual(Set(ExamenStep.allCases.map(\.poolKey)).count, 5, "each step has its own no-repeat bag")
        for step in ExamenStep.allCases {
            XCTAssertEqual(ExamenStep.step(poolKey: step.poolKey), step)
            XCTAssertFalse(step.caption.isEmpty)
        }
        XCTAssertNil(ExamenStep.step(poolKey: "quick"))
    }

    func testEveryStepHasAtLeastTwentyDistinctWarmLines() {
        var everyLine: [String] = []
        for step in ExamenStep.allCases {
            let lines = step.prompts
            XCTAssertGreaterThanOrEqual(lines.count, 20, "\(step) has \(lines.count)")
            XCTAssertEqual(Set(lines).count, lines.count, "no duplicates in \(step)")
            for line in lines {
                XCTAssertFalse(line.contains("{name}"), "nobody is picked in a night prayer: \(line)")
                XCTAssertTrue(line.hasSuffix(".") || line.hasSuffix("?") || line.hasSuffix("!"), "a whole sentence: \(line)")
                XCTAssertLessThanOrEqual(line.count, 140, "short enough to read at night: \(line)")
                for word in ["block", "hell", "failure", "lazy", "pathetic", "disappoint"] {
                    XCTAssertFalse(line.lowercased().contains(word), "\(word) in \(line)")
                }
            }
            everyLine += lines
        }
        XCTAssertEqual(Set(everyLine).count, everyLine.count, "no line is shared between steps")
    }

    func testTheEveningRunsFromEightUntilThree() {
        XCTAssertFalse(NightPrayer.isEvening(hour: 19))
        XCTAssertTrue(NightPrayer.isEvening(hour: 20))
        XCTAssertTrue(NightPrayer.isEvening(hour: 23))
        XCTAssertTrue(NightPrayer.isEvening(hour: 0))
        XCTAssertTrue(NightPrayer.isEvening(hour: 2))
        XCTAssertFalse(NightPrayer.isEvening(hour: 3))
        let cal = TestCalendar.newYork
        let late = TestCalendar.date(2026, 11, 19, 1, 30)
        XCTAssertEqual(NightPrayer.eveningKey(for: late, calendar: cal), TestCalendar.day(2026, 11, 18), "1:30 AM is still last night")
        XCTAssertEqual(NightPrayer.eveningKey(for: TestCalendar.date(2026, 11, 18, 21, 0), calendar: cal), TestCalendar.day(2026, 11, 18))
        XCTAssertEqual(NightPrayer.eveningKey(for: TestCalendar.date(2026, 11, 19, 4, 0), calendar: cal), TestCalendar.day(2026, 11, 19))
    }

    func testTheBedtimeLinkOpensNightPrayer() {
        XCTAssertEqual(DeepLink(url: AppLinks.nightPrayerDeepLink), .nightPrayer)
        XCTAssertEqual(DeepLink(url: URL(string: "prayscroll://examen")!), .nightPrayer)
        XCTAssertEqual(DeepLink(url: URL(string: "amenkey://night")!), .nightPrayer)
    }

    func testBedtimeReminderSettingsDecodeFromOlderSaves() throws {
        let old = try JSONDecoder().decode(ReminderSettings.self, from: Data(#"{"dailyEnabled":true,"dailyHour":7}"#.utf8))
        XCTAssertFalse(old.bedtimeEnabled, "off until they turn it on")
        XCTAssertEqual(old.bedtimeHour, 21)
        XCTAssertEqual(old.bedtimeMinute, 30)
        XCTAssertTrue(old.weeklyRecapEnabled)
        XCTAssertFalse(old.nudgeEnabled)
        var on = ReminderSettings()
        on.bedtimeEnabled = true
        on.bedtimeHour = 22
        let round = try JSONDecoder().decode(ReminderSettings.self, from: JSONEncoder().encode(on))
        XCTAssertEqual(round, on)
    }
}
