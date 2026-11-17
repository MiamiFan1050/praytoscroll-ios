// HOSTED-ONLY: StoryLibrary is main-actor and touches UNUserNotificationCenter, so tools/run-unit-tests.sh skips this file (CI runs it).
import XCTest
@testable import PrayToScroll

final class StoryLibraryTests: XCTestCase {
    @MainActor
    private func makeLibrary(_ defaults: UserDefaults = makeScratchDefaults()) -> StoryLibrary {
        StoryLibrary(defaults: defaults, bundle: Bundle(for: AppModel.self))
    }

    @MainActor
    func testBundledCatalogLoadsWithTwoFreePartsPerSeries() throws {
        let library = makeLibrary()
        XCTAssertFalse(library.series.isEmpty, "stories.json ships in the bundle, so the tab works before any fetch")
        XCTAssertFalse(library.notice.isEmpty, "the ESV credit line must be there")
        for series in library.series {
            XCTAssertGreaterThanOrEqual(series.episodes.count, 2, series.id)
            XCTAssertTrue(series.episodes.prefix(2).allSatisfy(\.free), "\(series.id): parts 1–2 are free")
            XCTAssertTrue(series.episodes.dropFirst(2).allSatisfy { !$0.free }, "\(series.id): later parts open with a prayer")
            for episode in series.episodes {
                XCTAssertNotNil(library.url(episode.video), episode.id)
                XCTAssertFalse(episode.prayer.isEmpty, "\(episode.id) needs its unlock prayer")
            }
        }
        let ids = library.series.flatMap { $0.episodes.map(\.id) }
        XCTAssertEqual(ids.count, Set(ids).count, "episode ids are unique")
    }

    @MainActor
    func testUnlockAndWatchPersistAndDriveContinue() throws {
        let defaults = makeScratchDefaults()
        let library = makeLibrary(defaults)
        let series = try XCTUnwrap(library.series.first { $0.episodes.count >= 3 })
        let third = series.episodes[2]
        XCTAssertFalse(library.isUnlocked(third))
        library.unlock(third.id)
        XCTAssertTrue(library.isUnlocked(third))

        XCTAssertNil(library.continueTarget, "nothing watched yet")
        library.markWatched(series.episodes[1])
        XCTAssertEqual(library.continueTarget?.episode.id, third.id, "continue = the part after the last one watched")
        XCTAssertEqual(library.watchedCount(in: series), 1)

        let reopened = makeLibrary(defaults)
        XCTAssertTrue(reopened.isUnlocked(third), "an unlock is forever")
        XCTAssertEqual(reopened.continueTarget?.episode.id, third.id)
    }

    @MainActor
    func testNeighboursAndLastPart() throws {
        let library = makeLibrary()
        let series = try XCTUnwrap(library.series.first)
        let first = try XCTUnwrap(series.episodes.first)
        let last = try XCTUnwrap(series.episodes.last)
        XCTAssertNil(library.previous(of: first, in: series))
        XCTAssertNil(library.next(after: last, in: series))
        XCTAssertEqual(library.next(after: first, in: series)?.id, series.episodes[1].id)
        library.markWatched(last)
        XCTAssertNil(library.continueTarget, "a finished series has nothing to continue")
    }
}
