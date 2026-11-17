import XCTest
@testable import PrayToScroll

/// The art the app asks for is in the asset catalog, small enough to ship, and the brand has no key imagery
/// (a key is a competitor's motif; ours is the sealed scroll).
final class BrandArtTests: XCTestCase {
    private var catalog: URL { SourceFiles.resource("Assets.xcassets") }

    private func imageset(_ name: String) -> URL { catalog.appendingPathComponent("\(name).imageset") }

    func testEveryArtNameTheAppUsesIsInTheCatalog() throws {
        var names = WordBadge.allCases.map(\.artName)
        names += (1...WordLevel.names.count).map { WordLevel.artName($0) }
        names += ["Onboarding-1", "Onboarding-2", "Onboarding-3", "Onboarding-4", "Empty-saved", "Empty-friends", "Empty-requests",
                  "SealScroll", "FlameStreak"]
        names += ["praying", "celebrating", "waving", "sleeping", "phone"].map { "Mascot-\($0)" }
        XCTAssertEqual(WordLevel.artName(1), "Level-01")
        XCTAssertEqual(WordLevel.artName(15), "Level-15")
        XCTAssertEqual(WordBadge.firstSave.artName, "Badge-firstSave")
        for name in names {
            let png = imageset(name).appendingPathComponent("\(name).png")
            XCTAssertTrue(FileManager.default.fileExists(atPath: png.path), "\(name) is in Assets.xcassets")
        }
    }

    /// Art ships at its display size (@3x of the largest point size), never the 1024 px source.
    func testArtIsDownscaledAndCompressed() throws {
        let sets = try FileManager.default.contentsOfDirectory(at: catalog, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "imageset" }
        XCTAssertGreaterThanOrEqual(sets.count, 42)
        var total = 0
        for set in sets {
            for file in try FileManager.default.contentsOfDirectory(at: set, includingPropertiesForKeys: nil) where file.pathExtension == "png" {
                let data = try Data(contentsOf: file)
                total += data.count
                XCTAssertLessThanOrEqual(data.count, 400_000, "\(file.lastPathComponent) is \(data.count) bytes")
                // PNG IHDR: width at bytes 16-19.
                let width = data[16...19].reduce(0) { $0 << 8 | Int($1) }
                XCTAssertLessThanOrEqual(width, 720, "\(file.lastPathComponent) is \(width) px wide")
            }
        }
        XCTAssertLessThanOrEqual(total, 6_000_000, "all catalog art together: \(total) bytes")
    }

    /// No key anywhere: no key SF Symbols, no drawn key, no key art name.
    func testNoKeyImagery() throws {
        let fm = FileManager.default
        var offenders: [String] = []
        for folder in ["PrayToScroll", "Shared", "PrayToScrollWidget", "StrictLock"] {
            let root = SourceFiles.app.appendingPathComponent(folder)
            guard let files = fm.enumerator(at: root, includingPropertiesForKeys: nil) else { continue }
            for case let file as URL in files where file.pathExtension == "swift" {
                let text = try String(contentsOf: file, encoding: .utf8)
                for needle in ["\"key.fill\"", "\"key\"", "\"key.horizontal", "\"key.radiowaves", "KeyShaft", "PadlockGold", "🔑"]
                where text.contains(needle) {
                    offenders.append("\(file.lastPathComponent): \(needle)")
                }
            }
        }
        XCTAssertEqual(offenders, [])
    }
}
