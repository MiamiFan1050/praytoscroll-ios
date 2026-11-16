import Foundation

/// One 60–90 second devotional (Unlock with → Devotional): our own title, ~120 words and a one-line prayer,
/// around one public-domain verse (World English Bible `text`, King James `kjv`, filled by tools/bible_text.py).
struct Devotional: Codable, Hashable, Identifiable, Sendable {
    var id: String
    var title: String
    var ref: String
    var theme: String
    var body: String
    var prayer: String
    var text: String
    var kjv: String?

    /// Everything on screen, for the minimum read time.
    var readingWords: Int { ReadingTime.wordCount([title, ref, text, body, prayer]) }

    static let fallback = Devotional(
        id: "fallback", title: "Be Still", ref: "Psalm 46:10", theme: "rest",
        body: "Most of the day asks you to do something: answer, scroll, react, keep up. This verse asks for the opposite. Be still. Not because nothing matters, but because God is God and you are not holding the world together. Stillness is not wasted time. It is trust you can practice. For the next minute, put the phone face down and let your breathing slow. Tell God one thing you have been gripping tightly, and picture setting it in his hands. You will pick your day back up in a moment, but you will pick it up as someone who is held, not someone who has to hold everything.",
        prayer: "God, you are God and I am not. Teach me to be still and trust you today. Amen.",
        text: "“Be still, and know that I am God. I will be exalted among the nations. I will be exalted in the earth.”",
        kjv: "Be still, and know that I am God: I will be exalted among the heathen, I will be exalted in the earth.")
}
