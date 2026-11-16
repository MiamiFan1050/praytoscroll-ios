import Foundation

/// Six-character invite codes for Prayer Circles. No 0/O or 1/I, so codes survive being read aloud.
enum CircleCode {
    static let alphabet: [Character] = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
    static let length = 6

    static func generate() -> String {
        var rng = SystemRandomNumberGenerator()
        return generate(using: &rng)
    }

    static func generate<G: RandomNumberGenerator>(using rng: inout G) -> String {
        String((0..<length).map { _ in alphabet.randomElement(using: &rng)! })
    }

    /// Cleans user input ("abc-23x", " ABC 23X ") into a valid code, or nil.
    static func normalize(_ input: String) -> String? {
        let cleaned = String(input.uppercased().filter { !$0.isWhitespace && $0 != "-" && $0 != "_" && $0 != "·" })
        guard cleaned.count == length, cleaned.allSatisfy({ alphabet.contains($0) }) else { return nil }
        return cleaned
    }

    static func isValid(_ code: String) -> Bool {
        code.count == length && code.allSatisfy { alphabet.contains($0) }
    }

    /// Pulls a code out of a pasted link (`https://…/join?c=CODE` or `prayscroll://join?c=CODE`) or plain text.
    static func extract(from text: String) -> String? {
        if let components = URLComponents(string: text.trimmingCharacters(in: .whitespacesAndNewlines)),
           let value = components.queryItems?.first(where: { $0.name.lowercased() == "c" || $0.name.lowercased() == "code" })?.value {
            return normalize(value)
        }
        return normalize(text)
    }

    /// Display form "ABC 23X".
    static func pretty(_ code: String) -> String {
        guard code.count == length else { return code }
        let mid = code.index(code.startIndex, offsetBy: 3)
        return String(code[..<mid]) + " " + String(code[mid...])
    }
}
