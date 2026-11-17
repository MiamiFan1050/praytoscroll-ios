import Foundation

/// The text that goes out after you pray for someone: "I just prayed for you 🙏", what you prayed (the prompt,
/// turned around to speak to them), and the app's link. The person only taps Send.
enum LetThemKnowMessage {
    static let opening = "I just prayed for you 🙏"
    /// Messages keeps long texts fine, but a prayer text should read in one glance.
    static let maxLength = 320

    /// Fallback when the prayer had no "for someone" prompt (a typed prayer, a switched method).
    static let fallbackLine = "I wanted you to know someone was thinking of you today."

    /// - Parameters:
    ///   - template: the raw prompts.json "forSomeone" line that was prayed (with `{name}`), if any.
    ///   - verse: a verse to send instead, when the prayer was built around one.
    static func build(template: String?, verse: Verse? = nil, link: URL) -> String {
        var middle = template.flatMap { lines[$0] } ?? fallbackLine
        if template == nil, let verse, verse.text.count <= 140 {
            middle = "\u{201C}\(verse.text)\u{201D} \(verse.ref)"
        }
        let text = "\(opening) \(middle)\n\n\(link.absoluteString)"
        return text.replacingOccurrences(of: "{name}", with: "you")
    }

    /// Every prompts.json "forSomeone" prompt, spoken to the person you prayed for. Unit tests check every
    /// prompt has one, so a new prompt needs a line here too.
    static let lines: [String: String] = [
        "Ask God to meet {name} in whatever they’re carrying right now.": "I asked God to meet you in whatever you’re carrying right now.",
        "Thank God for {name}, and for one thing you love about them.": "I thanked God for you, and for everything I love about you.",
        "Ask God to give {name} a peace that makes no sense on paper.": "I asked God to give you a peace that makes no sense on paper.",
        "Pray that {name} would feel loved today, by God and by the people around them.": "I prayed you’d feel loved today, by God and by the people around you.",
        "Ask God to give {name} rest, the deep kind.": "I asked God to give you rest, the deep kind.",
        "Pray for {name}’s heart to be guarded, healed and full.": "I prayed for your heart to be guarded, healed and full.",
        "Ask God to give {name} wisdom for the decisions in front of them.": "I asked God to give you wisdom for the decisions in front of you.",
        "Pray that {name} would know they’re not alone in what they’re facing.": "I prayed you’d know you’re not alone in what you’re facing.",
        "Ask God to protect {name} today, wherever they are.": "I asked God to protect you today, wherever you are.",
        "Pray that {name} would sleep well tonight and wake up with hope.": "I prayed you’d sleep well tonight and wake up with hope.",
        "Ask God to provide for {name}’s needs, the ones they’ve shared and the ones they haven’t.": "I asked God to provide for your needs, the ones you’ve shared and the ones you haven’t.",
        "Pray for {name}’s health: body, mind and spirit.": "I prayed for your health: body, mind and spirit.",
        "Ask God to give {name} courage for the hard thing they’re facing.": "I asked God to give you courage for whatever you’re facing.",
        "Pray that God would bring good friends around {name}.": "I prayed God would bring good friends around you.",
        "Ask God to bless {name}’s work and give them joy in it.": "I asked God to bless your work and give you joy in it.",
        "Pray for {name}’s family, and the relationships that matter most to them.": "I prayed for your family, and the relationships that matter most to you.",
        "Ask God to draw {name} closer to him, in his timing and his way.": "I asked God to draw you closer to him, in his timing and his way.",
        "Pray that {name} would hear God’s voice clearly this week.": "I prayed you’d hear God’s voice clearly this week.",
        "Ask God to heal whatever is hurting in {name}’s life right now.": "I asked God to heal whatever is hurting in your life right now.",
        "Pray that {name} would see themselves the way God sees them.": "I prayed you’d see yourself the way God sees you.",
        "Ask God to give {name} a reason to smile today.": "I asked God to give you a reason to smile today.",
        "Pray that {name}’s faith would grow stronger, not shakier, through this season.": "I prayed your faith would grow stronger, not shakier, through this season.",
        "Ask God to calm {name}’s anxious thoughts and steady their heart.": "I asked God to calm any anxious thoughts and steady your heart.",
        "Pray for {name}’s future: the plans they’re making and the dreams they’re holding.": "I prayed for your future: the plans you’re making and the dreams you’re holding.",
        "Ask God to wrap {name} in his kindness, like a warm coat on a cold day.": "I asked God to wrap you in his kindness, like a warm coat on a cold day.",
        "Pray that {name} would forgive and be forgiven wherever it’s needed.": "I prayed for grace and freedom wherever you need them.",
        "Ask God to give {name} strength for today. Just today.": "I asked God to give you strength for today. Just today.",
        "Pray that {name} would find joy in small things this week.": "I prayed you’d find joy in small things this week.",
        "Ask God to show you how you could be part of the answer to your prayer for {name}.": "I asked God to show me how I can be part of the answer for you.",
        "Pray for {name}’s mind to be clear and their heart to be light.": "I prayed for your mind to be clear and your heart to be light.",
        "Ask God to comfort {name} in any grief or loss they’re carrying.": "I asked God to comfort you in anything heavy you’re carrying.",
        "Pray that {name} would have the right words in the conversations that matter.": "I prayed you’d have the right words in the conversations that matter.",
        "Ask God to keep {name} safe as they travel, work and rest.": "I asked God to keep you safe as you travel, work and rest.",
        "Pray that {name} would experience God’s love in a way they can actually feel.": "I prayed you’d experience God’s love in a way you can actually feel.",
        "Ask God to break anything that’s holding {name} back.": "I asked God to break anything that’s holding you back.",
        "Pray for {name} to have patience, with others and with themselves.": "I prayed for patience for you, with others and with yourself.",
        "Ask God to open the right doors for {name} and gently close the wrong ones.": "I asked God to open the right doors for you and gently close the wrong ones.",
        "Thank God for the ways {name} has blessed your life. Then ask him to bless theirs.": "I thanked God for the ways you’ve blessed my life, and asked him to bless yours.",
        "Pray that {name} would feel hope rising, even if nothing has changed yet.": "I prayed you’d feel hope rising, even if nothing has changed yet.",
        "Ask God to give {name} a clear sense of purpose this week.": "I asked God to give you a clear sense of purpose this week.",
        "Pray that {name}’s home would be a place of peace.": "I prayed your home would be a place of peace.",
        "Ask God to remind {name} that they are deeply loved, right now, as they are.": "I asked God to remind you that you are deeply loved, right now, as you are.",
        "Pray for whatever {name} hasn’t told anyone. God already knows.": "I prayed for whatever’s on your heart, even the things you haven’t said.",
        "Ask God to give {name} good news soon, and grace while they wait.": "I asked God to give you good news soon, and grace while you wait.",
        "Pray that {name} would know someone was thinking of them today. Then maybe tell them.": "I wanted you to know someone was thinking of you today.",
        // The built-in fallback prompts (ContentStore), for when prompts.json can't load.
        "Ask God to meet {name} right where they are today.": "I asked God to meet you right where you are today.",
        "Pray for {name}'s heart: peace where there's worry, hope where there's tiredness.": "I prayed for peace where there’s worry, and hope where there’s tiredness.",
        "Ask for one specific good thing for {name} this week.": "I asked God for something good for you this week.",
    ]
}
