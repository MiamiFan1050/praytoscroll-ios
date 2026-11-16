import Foundation

/// A no-repeat shuffle bag: every prompt in a pool is used once before any prompt repeats,
/// and a new round never starts with the prompt that ended the last one.
enum PromptBag {
    static func draw<G: RandomNumberGenerator>(key: String, poolCount: Int, bags: inout [String: [Int]], using rng: inout G) -> Int {
        guard poolCount > 0 else { return 0 }
        let bagKey = "\(key)#\(poolCount)"
        let lastKey = bagKey + "#last"
        var remaining = (bags[bagKey] ?? []).filter { $0 >= 0 && $0 < poolCount }
        if remaining.isEmpty {
            remaining = Array(0..<poolCount).shuffled(using: &rng)
            // We draw from the end; don't let the new round open with the previous round's last prompt.
            if poolCount > 1, let last = bags[lastKey]?.first, remaining.last == last {
                remaining.swapAt(0, remaining.count - 1)
            }
        }
        let index = remaining.removeLast()
        // Forget bags for this key built for a different pool size (content was updated).
        for existing in bags.keys where existing.hasPrefix(key + "#") && existing != bagKey && existing != lastKey {
            bags.removeValue(forKey: existing)
        }
        bags[bagKey] = remaining
        bags[lastKey] = [index]
        return index
    }

    static func draw(key: String, poolCount: Int, bags: inout [String: [Int]]) -> Int {
        var rng = SystemRandomNumberGenerator()
        return draw(key: key, poolCount: poolCount, bags: &bags, using: &rng)
    }
}

extension SharedStore {
    /// Draws the next prompt from a pool without repeats, persisting the bag in the app group.
    func nextPrompt(key: String, from pool: [String]) -> String {
        guard !pool.isEmpty else { return "" }
        var bags = promptBags
        let index = PromptBag.draw(key: key, poolCount: pool.count, bags: &bags)
        promptBags = bags
        return pool[index]
    }
}
