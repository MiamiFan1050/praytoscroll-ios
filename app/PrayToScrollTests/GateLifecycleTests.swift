// HOSTED-ONLY: drives the real AppModel (SwiftData + app host), so tools/run-unit-tests.sh skips this file.
import SwiftData
import XCTest
@testable import PrayToScroll

/// The Prayer Gate end to end, through the same AppModel + SharedStore calls the App Intents and buttons make.
/// Each test gets the seeded demo (gate on for Instagram, TikTok, YouTube and X; a 15-minute window) in scratch defaults.
@MainActor
final class GateLifecycleTests: XCTestCase {
    private func makeModel() -> (AppModel, SharedStore) {
        let store = SharedStore(defaults: makeScratchDefaults())
        return (AppModel(options: LaunchOptions(arguments: ["-demo"]), store: store), store)
    }

    private func decide(_ app: String, _ store: SharedStore, at date: Date) -> GateDecision {
        GateEngine.decide(appID: app, now: date, snapshot: store.gateSnapshot)
    }

    private func reason(_ decision: GateDecision) -> AllowReason? {
        if case .allow(_, let reason) = decision { return reason }
        return nil
    }

    @discardableResult
    private func pray(_ model: AppModel, source: SessionSource = .gate, app: String? = "instagram") -> PrayerCompletion {
        let now = Date()
        return model.completePrayer(PrayerOutcome(style: .quick, source: source, gatedAppID: app,
                                                  startedAt: now.addingTimeInterval(-35), completedAt: now))
    }

    func testLockedPrayAmenOpensForTheWindowThenAsksAgain() throws {
        let (model, store) = makeModel()
        let start = Date()
        XCTAssertEqual(decide("instagram", store, at: start), .requirePrayer, "locked before any prayer")

        // The intent decided "pray first" and handed over to the app.
        store.setPendingGate(appID: "instagram", at: start)
        model.handleIntentContinuation(appID: "instagram", verify: false)
        XCTAssertEqual(model.activeSession?.source, .gate)
        XCTAssertEqual(model.activeSession?.gatedAppID, "instagram")
        XCTAssertNil(store.consumePendingGate(), "the hand-off consumes the pending gate, so it can't start twice")
        model.handleIntentContinuation(appID: "instagram", verify: false)
        XCTAssertEqual(model.activeSession?.gatedAppID, "instagram", "a second hand-off doesn't restart the prayer")

        // Amen.
        let completion = pray(model)
        let end = try XCTUnwrap(completion.unlockedUntil)
        XCTAssertEqual(end.timeIntervalSince(start), 15 * 60, accuracy: 5)
        XCTAssertEqual(store.unlockedUntil, end, "written to the app group before Continue can reopen the app")
        XCTAssertEqual(completion.gatedApp?.id, "instagram")

        XCTAssertEqual(reason(decide("instagram", store, at: start.addingTimeInterval(60))), .unlocked, "no prompt inside the window")
        XCTAssertEqual(reason(decide("instagram", store, at: end.addingTimeInterval(-1))), .unlocked)
        XCTAssertEqual(reason(decide("instagram", store, at: end.addingTimeInterval(10))), .grace)
        XCTAssertEqual(decide("instagram", store, at: end.addingTimeInterval(GateEngine.graceSeconds + 1)), .requirePrayer,
                       "the next open after the window asks for a prayer again")
        XCTAssertEqual(decide("instagram", store, at: end.addingTimeInterval(30 * 86_400)), .requirePrayer)
    }

    func testContinueAfterLingeringOpensOnceWithoutLooping() throws {
        let (model, store) = makeModel()
        model.updateSettings { $0.unlockWindowMinutes = 5 }
        let end = try XCTUnwrap(pray(model).unlockedUntil)
        // They read the celebration past the window, then tap "Continue to Instagram": openApp writes a 30 s pass first.
        let late = end.addingTimeInterval(120)
        store.grantLaunchPass(appID: "instagram", now: late)
        XCTAssertEqual(reason(decide("instagram", store, at: late.addingTimeInterval(2))), .launchPass, "no prayer loop on the way in")
        XCTAssertEqual(decide("instagram", store, at: late.addingTimeInterval(GateEngine.launchPassSeconds + 1)), .requirePrayer)
        XCTAssertEqual(decide("tiktok", store, at: late.addingTimeInterval(2)), .requirePrayer, "launch passes are per app")
    }

    func testOneWindowCoversEveryGatedAppAndEndsForAll() throws {
        let (model, store) = makeModel()
        let end = try XCTUnwrap(pray(model).unlockedUntil)
        for app in ["instagram", "tiktok", "youtube", "x"] {
            XCTAssertEqual(reason(decide(app, store, at: end.addingTimeInterval(-1))), .unlocked, app)
            XCTAssertEqual(decide(app, store, at: end.addingTimeInterval(GateEngine.graceSeconds + 1)), .requirePrayer, app)
        }
        XCTAssertEqual(reason(decide("reddit", store, at: end.addingTimeInterval(60))), .notGated, "apps off the list pass")
    }

    func testINeedItNowIsOnceADayLoggedAndEnds() throws {
        let (model, store) = makeModel()
        let usesBefore = store.emergencyUses
        let t0 = Date()
        XCTAssertTrue(model.canUseEmergencyPass)
        XCTAssertTrue(model.useEmergencyPass(for: nil))
        XCTAssertEqual(store.emergencyUses, usesBefore + 1, "logged for the stats")
        XCTAssertEqual(model.emergencyUses, usesBefore + 1)
        let lastUsed = try XCTUnwrap(store.emergencyLastUsed)
        XCTAssertEqual(lastUsed.timeIntervalSince(t0), 0, accuracy: 5)
        let end = try XCTUnwrap(store.unlockedUntil)
        XCTAssertEqual(end.timeIntervalSince(t0), Double(GateEngine.emergencyMinutes * 60), accuracy: 5)
        XCTAssertEqual(reason(decide("tiktok", store, at: end.addingTimeInterval(-1))), .unlocked)
        XCTAssertEqual(decide("tiktok", store, at: end.addingTimeInterval(GateEngine.graceSeconds + 1)), .requirePrayer)

        XCTAssertFalse(model.canUseEmergencyPass, "one a day")
        XCTAssertFalse(model.useEmergencyPass(for: nil))
        XCTAssertEqual(store.emergencyUses, usesBefore + 1, "a refused pass isn't counted")
        let next = try XCTUnwrap(GateEngine.nextEmergencyPassDate(now: Date(), lastUsed: lastUsed, calendar: .current))
        XCTAssertEqual(Calendar.current.component(.hour, from: next), 0, "comes back at local midnight")
        XCTAssertTrue(GateEngine.canUseEmergencyPass(now: next, lastUsed: lastUsed, calendar: .current))
        XCTAssertFalse(GateEngine.canUseEmergencyPass(now: next.addingTimeInterval(-1), lastUsed: lastUsed, calendar: .current))
    }

    func testDailyKeyOpensUntilTheResetHourThenAsksAgain() throws {
        let (model, store) = makeModel()
        model.updateSettings { $0.unlockMode = .dailyKey; $0.dailyKeyResetHour = 4 }
        let until = try XCTUnwrap(pray(model).unlockedUntil)
        XCTAssertEqual(Calendar.current.component(.hour, from: until), 4)
        XCTAssertLessThanOrEqual(until.timeIntervalSinceNow, 86_400 + 3_600)
        XCTAssertEqual(reason(decide("instagram", store, at: until.addingTimeInterval(-1))), .dailyKey)
        XCTAssertEqual(decide("instagram", store, at: until.addingTimeInterval(1)), .requirePrayer)
    }

    func testPauseIsAlwaysTimeBoundAndResumes() throws {
        let (model, store) = makeModel()
        model.pauseGate(days: 7)
        let paused = try XCTUnwrap(store.pausedUntil)
        XCTAssertEqual(reason(decide("instagram", store, at: Date().addingTimeInterval(60))), .paused)
        XCTAssertEqual(decide("instagram", store, at: paused.addingTimeInterval(1)), .requirePrayer)
        model.pauseGate(days: nil)
        XCTAssertEqual(decide("instagram", store, at: Date().addingTimeInterval(1)), .requirePrayer)
    }

    func testStreakGoesUpOnceADay() {
        let (model, _) = makeModel()
        let before = model.streak.current
        let gatesBefore = model.gatesHonoured
        XCTAssertFalse(model.streak.prayedToday)
        let first = pray(model, source: .manual, app: nil)
        XCTAssertEqual(first.previousStreak, before)
        XCTAssertEqual(model.streak.current, before + 1)
        XCTAssertTrue(model.streak.prayedToday)
        pray(model)
        pray(model, source: .manual, app: nil)
        XCTAssertEqual(model.streak.current, before + 1, "more prayers the same day don't add days")
        XCTAssertEqual(model.gatesHonoured, gatesBefore + 1, "the gate prayer counts as prayed-instead-of-scrolling")
    }

    func testEraseAllDataRemovesEverythingAndCircleRowsBeforeTheID() async throws {
        let (model, store) = makeModel()
        XCTAssertGreaterThan(try model.context.fetchCount(FetchDescriptor<SavedVerse>()), 0)
        store.circleCodes = ["K7Q2MX"]
        let memberID = store.circleMemberID
        model.resetAllData()
        XCTAssertEqual(try model.context.fetchCount(FetchDescriptor<SavedVerse>()), 0, "saved verses are erased too")
        XCTAssertEqual(try model.context.fetchCount(FetchDescriptor<Person>()), 0)
        XCTAssertEqual(try model.context.fetchCount(FetchDescriptor<PrayerSession>()), 0)
        XCTAssertFalse(model.settings.hasOnboarded)
        XCTAssertEqual(store.circleMemberID, memberID, "kept until my circle rows are deleted")
        try await Task.sleep(nanoseconds: 500_000_000)
        XCTAssertNotEqual(store.circleMemberID, memberID, "then forgotten")
        XCTAssertEqual(model.streak.current, 0)
    }
}
