import XCTest
@testable import PrayToScroll

final class ChallengeTests: XCTestCase {
    private let cal = TestCalendar.newYork

    func testSevenDayChallengeCountsPrayedDaysInsideTheWindow() {
        let definition = ChallengeDefinition(id: "seven-days", title: "7 Days of Prayer", days: 7, description: "", tips: [])
        XCTAssertEqual(definition.metric, .prayedDays)
        XCTAssertEqual(definition.target, 7)
        let start = TestCalendar.date(2026, 11, 10, 9, 0)
        let prayed: Set<DayKey> = [TestCalendar.day(2026, 11, 9), TestCalendar.day(2026, 11, 10), TestCalendar.day(2026, 11, 11),
                                   TestCalendar.day(2026, 11, 12)]
        let p = ChallengeEngine.progress(definition: definition, startedAt: start, now: TestCalendar.date(2026, 11, 12, 20, 0),
                                         prayedDays: prayed, peoplePrayedFor: [], calendar: cal)
        XCTAssertEqual(p.completed, 3, "Nov 9 is before the challenge started")
        XCTAssertEqual(p.dayIndex, 3)
        XCTAssertTrue(p.completedToday)
        XCTAssertFalse(p.isComplete)
        XCTAssertFalse(p.isExpired)
        XCTAssertEqual(p.remaining, 4)
    }

    func testChallengeExpiresWhenTheTargetCantBeReached() {
        let definition = ChallengeDefinition(id: "seven-days", title: "7 Days", days: 7, description: "", tips: [])
        let start = TestCalendar.date(2026, 11, 10, 9, 0)
        let prayed: Set<DayKey> = [TestCalendar.day(2026, 11, 10)]
        let p = ChallengeEngine.progress(definition: definition, startedAt: start, now: TestCalendar.date(2026, 11, 12, 9, 0),
                                         prayedDays: prayed, peoplePrayedFor: [], calendar: cal)
        XCTAssertTrue(p.isExpired, "missed Nov 11: 1 done + 5 days left < 7")
    }

    func testDistinctPeopleChallenge() {
        let definition = ChallengeDefinition(id: "pray-for-people", title: "Pray for 5 people", days: 7, description: "", tips: [],
                                             target: 5)
        XCTAssertEqual(definition.metric, .distinctPeople)
        let start = TestCalendar.date(2026, 11, 10, 9, 0)
        let people: [(name: String, date: Date)] = [
            ("Mom", TestCalendar.date(2026, 11, 10, 10, 0)),
            ("mom ", TestCalendar.date(2026, 11, 11, 10, 0)),
            ("Jake", TestCalendar.date(2026, 11, 11, 11, 0)),
            ("Old friend", TestCalendar.date(2026, 11, 1, 11, 0)),
        ]
        let p = ChallengeEngine.progress(definition: definition, startedAt: start, now: TestCalendar.date(2026, 11, 11, 20, 0),
                                         prayedDays: [], peoplePrayedFor: people, calendar: cal)
        XCTAssertEqual(p.completed, 2)
        XCTAssertTrue(p.completedToday)
    }
}
