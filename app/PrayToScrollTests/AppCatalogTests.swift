import XCTest
@testable import PrayToScroll

/// The "Add another" list: names people search for, each with a well-formed, unique URL scheme or none.
final class AppCatalogTests: XCTestCase {
    func testTheAddAnotherListIsBigAndHasNoDuplicates() {
        XCTAssertGreaterThanOrEqual(AppCatalog.more.count, 40)
        let ids = AppCatalog.all.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count, "ids are unique across featured + more")
        let names = AppCatalog.all.map { $0.name.lowercased() }
        XCTAssertEqual(Set(names).count, names.count, "names are unique")
        XCTAssertTrue(AppCatalog.more.allSatisfy { !$0.isCustom && !$0.hasPresetIntent })
        XCTAssertTrue(AppCatalog.featured.allSatisfy(\.hasPresetIntent))
    }

    func testEverySchemeIsWellFormedAndUnique() {
        var schemes: [String] = []
        for app in AppCatalog.all where !app.urlString.isEmpty {
            XCTAssertTrue(app.urlString.hasSuffix("://"), "\(app.name): \(app.urlString)")
            XCTAssertEqual(GatedApp.normalizeScheme(app.urlString), app.urlString, "\(app.name) is already normalized")
            XCTAssertTrue(GatedApp.isValidScheme(app.urlString), app.name)
            XCTAssertNotNil(app.openURL, app.name)
            let scheme = String(app.urlString.dropLast(3))
            XCTAssertTrue(scheme.allSatisfy { $0.isLowercase || $0.isNumber || "-.+".contains($0) }, app.name)
            schemes.append(scheme)
        }
        XCTAssertEqual(Set(schemes).count, schemes.count, "no two apps share a scheme")
        XCTAssertFalse(schemes.contains(AppConstants.urlScheme), "never our own scheme")
        XCTAssertGreaterThanOrEqual(schemes.count, 30)
    }

    func testAppsWithoutASchemeHaveNoOpenURL() {
        let other = GatedApp.named("  Church Center ")
        XCTAssertEqual(other.name, "Church Center")
        XCTAssertNil(other.openURL, "after the Amen: \"Now open Church Center\"")
        XCTAssertTrue(other.isCustom)
        XCTAssertFalse(other.hasPresetIntent)
        XCTAssertEqual(other.id, "custom-churchcenter")
    }

    func testSearchFindsAppsByAnyWordAndSkipsAddedOnes() {
        XCTAssertEqual(AppCatalog.search("disc").first?.id, "discord")
        XCTAssertTrue(AppCatalog.search("video").contains { $0.id == "primevideo" }, "matches a later word")
        XCTAssertTrue(AppCatalog.search("POKEMON").contains { $0.id == "pokemongo" }, "case and accent insensitive")
        XCTAssertTrue(AppCatalog.search("disney").contains { $0.id == "disneyplus" })
        XCTAssertFalse(AppCatalog.search("disc", excluding: ["discord"]).contains { $0.id == "discord" })
        XCTAssertEqual(AppCatalog.search("").count, AppCatalog.more.count, "an empty search lists everything")
        let all = AppCatalog.search("").map(\.name)
        XCTAssertEqual(all, all.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }, "A to Z")
        XCTAssertTrue(AppCatalog.search("zzzz").isEmpty)
    }

    func testAddedCatalogAppsAreKnownToTheGate() {
        XCTAssertEqual(AppCatalog.app(id: "discord")?.name, "Discord")
        XCTAssertEqual(GateEngine.canonicalID("Discord", customApps: []), "discord")
    }
}
