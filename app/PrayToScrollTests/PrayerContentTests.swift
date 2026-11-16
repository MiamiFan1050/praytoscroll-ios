import XCTest
@testable import PrayToScroll

/// v1.1 prayer content: topic prompts, the Advent journey (calendar-gated), and the circle request filter.
final class PrayerContentTests: XCTestCase {
    private var content: ContentStore { ContentStore(bundle: Bundle(for: AppModel.self)) }

    // MARK: Topics

    func testEveryTopicHasItsOwnPromptsInHouseStyle() {
        let library = content.prompts
        var all: [String] = []
        for topic in PrayerTopic.allCases {
            let prompts = library.prompts(for: topic)
            XCTAssertGreaterThanOrEqual(prompts.count, 40, topic.rawValue)
            XCTAssertNotEqual(prompts, library.quick, "\(topic.rawValue) has its own pool, not the quick fallback")
            XCTAssertEqual(Set(prompts).count, prompts.count, "no repeats in \(topic.rawValue)")
            for prompt in prompts {
                XCTAssertFalse(prompt.contains("{name}"), "topic prompts are for you: \(prompt)")
                XCTAssertFalse(prompt.contains("—") || prompt.contains("–"), "house style: \(prompt)")
                XCTAssertTrue((30...140).contains(prompt.count), "\(topic.rawValue): \(prompt)")
            }
            all += prompts
        }
        XCTAssertEqual(Set(all).count, all.count, "no prompt is shared between topics")
        XCTAssertGreaterThanOrEqual(library.adoration.count, 60)
        XCTAssertGreaterThanOrEqual(library.supplication.count, 60)
    }

    func testTopicsFallBackToQuickPromptsWhenMissing() throws {
        let json = #"{"adoration":["a"],"confession":["c"],"thanksgiving":["t"],"supplication":["s"],"quick":["q1","q2"]}"#
        let library = try JSONDecoder().decode(PromptLibrary.self, from: Data(json.utf8))
        XCTAssertTrue(library.topics.isEmpty)
        XCTAssertEqual(library.prompts(for: .healing), ["q1", "q2"])
    }

    func testMorningAndNightFollowTheClock() {
        XCTAssertEqual(PrayerTopic.timeOfDay(hour: 3), .night)
        XCTAssertEqual(PrayerTopic.timeOfDay(hour: 4), .morning)
        XCTAssertEqual(PrayerTopic.timeOfDay(hour: 10), .morning)
        XCTAssertNil(PrayerTopic.timeOfDay(hour: 11))
        XCTAssertNil(PrayerTopic.timeOfDay(hour: 19))
        XCTAssertEqual(PrayerTopic.timeOfDay(hour: 20), .night)
        XCTAssertEqual(PrayerTopic.timeOfDay(hour: 23), .night)
        XCTAssertEqual(PrayerTopic.timeOfDay(hour: 0), .night)
    }

    // MARK: Advent

    func testAdventIsTwentySixDaysOfRealText() {
        let days = content.advent
        XCTAssertEqual(days.count, 26)
        let calendar = TestCalendar.newYork
        var date = TestCalendar.date(2026, 11, 29)
        for day in days {
            let parts = calendar.dateComponents([.month, .day], from: date)
            XCTAssertEqual(day.date, String(format: "%02d-%02d", parts.month!, parts.day!), "one reading per day, in order")
            XCTAssertGreaterThan(day.text.count, 30, day.ref)
            XCTAssertFalse(day.text.contains("Yahweh"), day.ref)
            XCTAssertGreaterThan(day.kjv?.count ?? 0, 30, day.ref)
            XCTAssertFalse(day.kjv?.contains("[") ?? true, day.ref)
            XCTAssertFalse(day.title.isEmpty || day.prompt.isEmpty, day.ref)
            XCTAssertTrue(["Hope", "Peace", "Joy", "Love"].contains(day.week), day.ref)
            date = calendar.date(byAdding: .day, value: 1, to: date)!
        }
        XCTAssertEqual(days.last?.date, "12-24")
    }

    func testAdventShowsOnlyFromNovember29ToDecember24() {
        let days = content.advent
        let calendar = TestCalendar.newYork
        func today(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12) -> Int? {
            AdventPlan.today(TestCalendar.date(y, m, d, h), calendar: calendar, days: days)?.index
        }
        XCTAssertNil(today(2026, 11, 28, 23))
        XCTAssertEqual(today(2026, 11, 29, 0), 0, "starts at midnight on Nov 29")
        XCTAssertEqual(today(2026, 12, 1), 2)
        XCTAssertEqual(today(2026, 12, 24, 23), 25, "ends with Christmas Eve")
        XCTAssertNil(today(2026, 12, 25, 0))
        XCTAssertNil(today(2027, 1, 5))
        XCTAssertNil(today(2027, 7, 4))
        XCTAssertEqual(today(2027, 11, 29), 0, "the same dates every year")
        XCTAssertNil(AdventPlan.today(TestCalendar.date(2026, 12, 3), calendar: calendar, days: []), "no content, no card")
    }

    func testAdventCountsOnlyThisSeasonsPrayedDays() {
        let calendar = TestCalendar.newYork
        let prayed: Set<DayKey> = [
            TestCalendar.day(2025, 12, 10),     // last year
            TestCalendar.day(2026, 11, 20),     // before Advent
            TestCalendar.day(2026, 11, 29),
            TestCalendar.day(2026, 12, 2),
            TestCalendar.day(2026, 12, 3),
            TestCalendar.day(2026, 12, 9),      // after "today"
        ]
        XCTAssertEqual(AdventPlan.daysPrayed(prayed, through: TestCalendar.date(2026, 12, 3), calendar: calendar), 3)
    }

    func testAnAdventDayPraysInTheChosenTranslation() throws {
        let day = try XCTUnwrap(content.advent.first)
        XCTAssertEqual(AdventPlan.verse(for: day, index: 0, translation: .web).displayText, day.text)
        XCTAssertEqual(AdventPlan.verse(for: day, index: 0, translation: .kjv).displayText, day.kjv)
        XCTAssertEqual(AdventPlan.verse(for: day, index: 0, translation: .web).ref, day.ref)
    }

    // MARK: Circle request filter

    func testRequestLinesAllowOrdinaryPrayerNeeds() {
        for line in ["My grandma's surgery on Friday", "Therapist appointment Tuesday", "Finals week, class of 2027",
                     "Assignment due and I'm behind", "Peace for my family 🙏", "Scunthorpe trip", ""] {
            XCTAssertNil(RequestNoteFilter.problem(with: line), line)
        }
    }

    func testRequestLinesBlockLinksContactsAndBadWords() {
        XCTAssertEqual(RequestNoteFilter.problem(with: "see https://example.com"), .link)
        XCTAssertEqual(RequestNoteFilter.problem(with: "go to mysite.com now"), .link)
        XCTAssertEqual(RequestNoteFilter.problem(with: "www dot thing dot com"), .link)
        XCTAssertEqual(RequestNoteFilter.problem(with: "dm me @grace_22"), .contact)
        XCTAssertEqual(RequestNoteFilter.problem(with: "me at grace@mail.co"), .contact)
        XCTAssertEqual(RequestNoteFilter.problem(with: "text 555 123 4567"), .contact)
        XCTAssertEqual(RequestNoteFilter.problem(with: "this shit week"), .notAllowed)
        XCTAssertEqual(RequestNoteFilter.problem(with: String(repeating: "a", count: 81)), .tooLong)
        XCTAssertEqual(RequestNoteFilter.clean("  two   spaces \n here "), "two spaces here")
    }

    func testRequestSummaries() {
        var request = CirclePrayerRequest(id: "r", circleCode: "K7Q2MX", memberID: "m", displayName: "Sarah", emoji: "🌻",
                                          topic: .gratitude, note: "", createdAt: Date(), prayedCount: 0, iPrayed: false, isMine: false)
        XCTAssertEqual(request.summary, "Praise")
        request.topic = .healing
        request.note = "Grandma's surgery"
        XCTAssertEqual(request.summary, "Healing: Grandma's surgery")
        XCTAssertFalse(request.isExpired)
        request.createdAt = Date().addingTimeInterval(-8 * 86_400)
        XCTAssertTrue(request.isExpired, "requests drop off after a week")
        XCTAssertFalse(PrayerTopic.requestTopics.contains(.morning))
    }

    // MARK: Mock circle requests (the demo + UI-test backend)

    func testMockCircleRequestsCountOnePrayerPerMemberAndCapOpenRequests() throws {
        let service = MockCircleService.demo()
        let code = "K7Q2MX"
        let first = try run { try await service.requests(code: code) }
        XCTAssertEqual(first.count, 3)
        let sarah = try XCTUnwrap(first.first { $0.displayName == "Sarah" })
        try run { try await service.prayed(for: sarah) }
        try run { try await service.prayed(for: sarah) }
        let after = try XCTUnwrap(try run { try await service.requests(code: code) }.first { $0.id == sarah.id })
        XCTAssertEqual(after.prayedCount, sarah.prayedCount + 1, "praying twice counts once")
        XCTAssertTrue(after.iPrayed)

        for note in ["One", "Two", "Three"] {
            _ = try run { try await service.postRequest(code: code, topic: .work, note: note, displayName: "Mark", emoji: "🕊️") }
        }
        XCTAssertEqual(postError(service, code, "Four"), .tooManyRequests, "3 open requests per person")
        let oldest = try XCTUnwrap(try run { try await service.requests(code: code) }.first(where: \.isMine))
        try run { try await service.deleteRequest(oldest) }
        XCTAssertEqual(postError(service, code, "call 5551234567"), .nameNotAllowed, "the filter runs on the server side too")
        _ = try run { try await service.postRequest(code: code, topic: .work, note: "Three again", displayName: "Mark", emoji: "🕊️") }

        let mine = try run { try await service.requests(code: code) }.filter(\.isMine)
        XCTAssertEqual(mine.count, 3)
        try run { try await service.deleteRequest(mine[0]) }
        try run { try await service.deleteRequest(sarah) }
        let left = try run { try await service.requests(code: code) }
        XCTAssertEqual(left.filter(\.isMine).count, 2)
        XCTAssertTrue(left.contains { $0.id == sarah.id }, "you can only remove your own")

        try run { try await service.leave(code: code) }
        XCTAssertTrue(try run { try await service.requests(code: code) }.allSatisfy { !$0.isMine }, "leaving removes your requests")
    }

    private func postError(_ service: MockCircleService, _ code: String, _ note: String) -> CircleError? {
        do {
            _ = try run { try await service.postRequest(code: code, topic: .work, note: note, displayName: "Mark", emoji: "🕊️") }
            return nil
        } catch {
            return error as? CircleError
        }
    }

    /// Runs async service code from a synchronous test (the local runner has no async tests).
    private func run<T: Sendable>(_ body: @escaping @Sendable () async throws -> T) throws -> T {
        let done = DispatchSemaphore(value: 0)
        let box = ResultBox<T>()
        Task.detached {
            do { box.result = .success(try await body()) } catch { box.result = .failure(error) }
            done.signal()
        }
        done.wait()
        return try box.result!.get()
    }
}

private final class ResultBox<T>: @unchecked Sendable {
    var result: Result<T, Error>?
}
