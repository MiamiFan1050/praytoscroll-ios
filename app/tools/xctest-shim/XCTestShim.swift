// A tiny stand-in for XCTest so the unit tests can be typechecked AND run without Xcode
// (tools/typecheck.sh tests / tools/run-unit-tests.sh). Only what our tests use.
import Foundation

class XCTestCase {
    var name: String = ""
    required init() {}
    func setUp() {}
    func tearDown() {}
}

struct XCTSkip: Error { var message: String; init(_ message: String = "") { self.message = message } }
struct XCTUnwrapError: Error, CustomStringConvertible { var description: String }

enum ShimResults {
    nonisolated(unsafe) static var failures: [String] = []
    nonisolated(unsafe) static var current = ""
    static func fail(_ message: String, _ file: StaticString, _ line: UInt) {
        failures.append("\(current) \(("\(file)" as NSString).lastPathComponent):\(line): \(message)")
    }
}

func XCTFail(_ message: String = "", file: StaticString = #filePath, line: UInt = #line) {
    ShimResults.fail("XCTFail \(message)", file, line)
}

func XCTAssertTrue(_ expression: @autoclosure () throws -> Bool, _ message: @autoclosure () -> String = "", file: StaticString = #filePath, line: UInt = #line) {
    let value = (try? expression()) ?? false
    if !value { ShimResults.fail("XCTAssertTrue failed \(message())", file, line) }
}

func XCTAssertFalse(_ expression: @autoclosure () throws -> Bool, _ message: @autoclosure () -> String = "", file: StaticString = #filePath, line: UInt = #line) {
    let value = (try? expression()) ?? true
    if value { ShimResults.fail("XCTAssertFalse failed \(message())", file, line) }
}

func XCTAssertEqual<T: Equatable>(_ a: @autoclosure () throws -> T, _ b: @autoclosure () throws -> T, _ message: @autoclosure () -> String = "", file: StaticString = #filePath, line: UInt = #line) {
    do {
        let x = try a(), y = try b()
        if x != y { ShimResults.fail("XCTAssertEqual failed: (\(x)) is not equal to (\(y)) \(message())", file, line) }
    } catch { ShimResults.fail("threw \(error)", file, line) }
}

func XCTAssertEqual<T: FloatingPoint>(_ a: @autoclosure () throws -> T, _ b: @autoclosure () throws -> T, accuracy: T, _ message: @autoclosure () -> String = "", file: StaticString = #filePath, line: UInt = #line) {
    do {
        let x = try a(), y = try b()
        if abs(x - y) > accuracy { ShimResults.fail("XCTAssertEqual(accuracy) failed: \(x) vs \(y) \(message())", file, line) }
    } catch { ShimResults.fail("threw \(error)", file, line) }
}

func XCTAssertNotEqual<T: Equatable>(_ a: @autoclosure () throws -> T, _ b: @autoclosure () throws -> T, _ message: @autoclosure () -> String = "", file: StaticString = #filePath, line: UInt = #line) {
    do {
        let x = try a(), y = try b()
        if x == y { ShimResults.fail("XCTAssertNotEqual failed: both \(x) \(message())", file, line) }
    } catch { ShimResults.fail("threw \(error)", file, line) }
}

func XCTAssertNil(_ expression: @autoclosure () throws -> Any?, _ message: @autoclosure () -> String = "", file: StaticString = #filePath, line: UInt = #line) {
    if let value = try? expression() { ShimResults.fail("XCTAssertNil failed: \(value) \(message())", file, line) }
}

func XCTAssertNotNil(_ expression: @autoclosure () throws -> Any?, _ message: @autoclosure () -> String = "", file: StaticString = #filePath, line: UInt = #line) {
    if (try? expression()) == nil { ShimResults.fail("XCTAssertNotNil failed \(message())", file, line) }
}

func XCTAssertGreaterThanOrEqual<T: Comparable>(_ a: @autoclosure () throws -> T, _ b: @autoclosure () throws -> T, _ message: @autoclosure () -> String = "", file: StaticString = #filePath, line: UInt = #line) {
    do {
        let x = try a(), y = try b()
        if x < y { ShimResults.fail("XCTAssertGreaterThanOrEqual failed: \(x) < \(y) \(message())", file, line) }
    } catch { ShimResults.fail("threw \(error)", file, line) }
}

func XCTAssertGreaterThan<T: Comparable>(_ a: @autoclosure () throws -> T, _ b: @autoclosure () throws -> T, _ message: @autoclosure () -> String = "", file: StaticString = #filePath, line: UInt = #line) {
    do {
        let x = try a(), y = try b()
        if !(x > y) { ShimResults.fail("XCTAssertGreaterThan failed: \(x) <= \(y) \(message())", file, line) }
    } catch { ShimResults.fail("threw \(error)", file, line) }
}

func XCTAssertLessThanOrEqual<T: Comparable>(_ a: @autoclosure () throws -> T, _ b: @autoclosure () throws -> T, _ message: @autoclosure () -> String = "", file: StaticString = #filePath, line: UInt = #line) {
    do {
        let x = try a(), y = try b()
        if x > y { ShimResults.fail("XCTAssertLessThanOrEqual failed: \(x) > \(y) \(message())", file, line) }
    } catch { ShimResults.fail("threw \(error)", file, line) }
}

func XCTUnwrap<T>(_ expression: @autoclosure () throws -> T?, _ message: @autoclosure () -> String = "", file: StaticString = #filePath, line: UInt = #line) throws -> T {
    guard let value = try expression() else {
        ShimResults.fail("XCTUnwrap failed \(message())", file, line)
        throw XCTUnwrapError(description: "nil")
    }
    return value
}
