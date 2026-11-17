import XCTest
@testable import PrayToScroll

/// The art the app asks for is in the asset catalog, small enough to ship, and the brand has no key imagery
/// (a key is a competitor's motif; ours is the sealed scroll).
final class BrandArtTests: XCTestCase {
    private let app = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    private var catalog: URL { app.appendingPathComponent("PrayToScroll/Resources/Assets.xcassets") }

    func testEveryArtNameTheAppUsesIsInTheCatalog() {
        let names = ["SealScroll", "FlameStreak"] + ["praying", "celebrating", "waving", "sleeping", "phone"].map { "Mascot-\($0)" }
        for name in names {
            let png = catalog.appendingPathComponent("\(name).imageset/\(name).png")
            XCTAssertTrue(FileManager.default.fileExists(atPath: png.path), "\(name) is in Assets.xcassets")
        }
    }

    /// Art ships at its display size (@3x of the largest point size), never the 1024 px source.
    func testArtIsDownscaledAndCompressed() throws {
        let sets = try FileManager.default.contentsOfDirectory(at: catalog, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "imageset" }
        XCTAssertGreaterThanOrEqual(sets.count, 7)
        for set in sets {
            for file in try FileManager.default.contentsOfDirectory(at: set, includingPropertiesForKeys: nil) where file.pathExtension == "png" {
                let data = try Data(contentsOf: file)
                XCTAssertLessThanOrEqual(data.count, 400_000, "\(file.lastPathComponent) is \(data.count) bytes")
                let width = data[16...19].reduce(0) { $0 << 8 | Int($1) }   // PNG IHDR width
                XCTAssertLessThanOrEqual(width, 720, "\(file.lastPathComponent) is \(width) px wide")
            }
        }
    }

    /// No key anywhere: no key SF Symbols, no drawn key, no key art name.
    func testNoKeyImagery() throws {
        var offenders: [String] = []
        for folder in ["PrayToScroll", "Shared", "PrayToScrollWidget", "StrictLock"] {
            guard let files = FileManager.default.enumerator(at: app.appendingPathComponent(folder), includingPropertiesForKeys: nil) else { continue }
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
