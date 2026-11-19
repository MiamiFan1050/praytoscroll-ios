import Foundation

/// Night prayer: a short evening Examen in five steps (thank, look back, sorry, ask, tomorrow). Each step has its own
/// no-repeat prompt bag, so a nightly habit doesn't hear the same line for weeks. All lines are written for this app.
enum ExamenStep: String, CaseIterable, Identifiable, Sendable {
    case thank, lookBack, sorry, ask, tomorrow

    var id: String { rawValue }
    var poolKey: String { "examen.\(rawValue)" }

    var title: String {
        switch self {
        case .thank: return "Thank"
        case .lookBack: return "Look back"
        case .sorry: return "Sorry"
        case .ask: return "Ask"
        case .tomorrow: return "Tomorrow"
        }
    }

    var caption: String {
        switch self {
        case .thank: return "Notice the gifts in today"
        case .lookBack: return "Walk through today with God"
        case .sorry: return "Bring it into the light"
        case .ask: return "For what you and others need"
        case .tomorrow: return "Hand it over and rest"
        }
    }

    var symbol: String {
        switch self {
        case .thank: return "gift.fill"
        case .lookBack: return "clock.arrow.circlepath"
        case .sorry: return "drop.fill"
        case .ask: return "hands.and.sparkles.fill"
        case .tomorrow: return "moon.stars.fill"
        }
    }

    var prompts: [String] {
        switch self {
        case .thank: return NightPrayer.thank
        case .lookBack: return NightPrayer.lookBack
        case .sorry: return NightPrayer.sorry
        case .ask: return NightPrayer.ask
        case .tomorrow: return NightPrayer.tomorrow
        }
    }

    static func step(poolKey: String) -> ExamenStep? {
        allCases.first { $0.poolKey == poolKey }
    }
}

enum NightPrayer {
    /// About two and a half minutes across the five steps.
    static let seconds = 150
    static let title = "Night prayer"

    /// Home suggests it from 8 PM until 3 AM.
    static func isEvening(hour: Int) -> Bool { hour >= 20 || hour < 3 }

    /// The evening a moment belongs to: 1:30 AM still counts as last night.
    static func eveningKey(for date: Date, calendar: Calendar) -> DayKey {
        DayKey(calendar.date(byAdding: .hour, value: -3, to: date) ?? date, calendar: calendar)
    }

    static let thank = [
        "Before anything else, thank God for one good moment from today, however small.",
        "Who made today a little lighter? Thank God for them by name.",
        "Think of a meal, a laugh or a kind word from today. Say thank you for it.",
        "You woke up this morning and made it to tonight. Thank Him for carrying you through.",
        "What did you see today that was beautiful? Thank the One who made it.",
        "Thank God for a need He met today, even one you're only noticing now.",
        "Name three small gifts from today. Let each one be a thank you.",
        "Thank Him for your body: the breath in your lungs, the steps you took, the sleep that's coming.",
        "Was there a moment today when you felt at peace? Thank God for it.",
        "Thank God for someone who may have prayed for you today without you knowing.",
        "Every good gift comes from above. Name one you were given today.",
        "Thank Him for a hard moment you got through. He was with you in it.",
        "Thank God for your home tonight, whatever it looks like.",
        "Think of a conversation from today. Thank God for the person on the other side of it.",
        "Thank Him for something new you learned today.",
        "His mercy was new this morning, and it covered all of today. Thank Him for that.",
        "Who do you love most? Thank God that they're in your life.",
        "Thank Him for a moment of rest or quiet you had today.",
        "Thank God for His Word, and for any line of it that stayed with you today.",
        "Thank Him for the people you'll see tomorrow.",
        "Look for one surprise from today. Thank God for it.",
        "Say it slowly and mean it: thank You, Lord, for today.",
    ]

    static let lookBack = [
        "Walk through your day from the morning on. Where did you feel close to God?",
        "Replay today like a short film. Which moment stands out? Ask God what He wants you to see in it.",
        "When did you feel most alive today? When did you feel drained? Tell God about both.",
        "Where did you see God at work today, in you or in someone else?",
        "Think about how you spent your time today. Show it to God, without judging it.",
        "Was there a moment you reached for your phone to get away from something? Tell God what you were feeling.",
        "Who did you meet today? Bring each face to God for a moment.",
        "What took most of your attention today? Hold it up to God.",
        "When were you patient today, and when weren't you? Look at both with Him.",
        "What did you worry about today? Notice how much of it never happened.",
        "Where did you choose love today, even in a small way?",
        "Look back at your words today. Which ones built someone up?",
        "Was there a moment God was nudging you? What do you think He was saying?",
        "What feeling is strongest in you right now? Tell God where it came from.",
        "Think of the hardest part of today. Picture Jesus there with you in it.",
        "Where did you rush today? Where did you slow down?",
        "Find one moment from today you'd gladly live again. Thank God it happened.",
        "Did anything today remind you of heaven, even for a second?",
        "Who needed you today? How did you show up for them?",
        "What did you hope for this morning? How did the day answer it?",
        "Ask God to show you today the way He saw it.",
        "Go back to the last hour. What was on your heart?",
    ]

    static let sorry = [
        "Is there a moment from today you wish you could redo? Tell God, and receive His mercy.",
        "Bring God one thing you're sorry for. He is faithful to forgive.",
        "Was there a word you said today that you'd take back? Give it to God.",
        "Where did something else take God's place today? Turn back to Him now.",
        "Is there someone you hurt today, even a little? Ask God for a way to make it right.",
        "Name one thing you did today out of fear instead of trust. Let it go.",
        "Was there a time today you knew the right thing and didn't do it? Tell Him honestly.",
        "If you're carrying shame from today, set it down. God already knows, and He still calls you His.",
        "Was there a moment someone needed you and you missed it? Ask for eyes to see them tomorrow.",
        "Bring God any thought today that pulled you away from Him. He makes all things new.",
        "Is there someone you need to forgive tonight? Ask God to help you start.",
        "Tell God where you were impatient today. Receive His patience with you.",
        "As far as the east is from the west, that's how far He sends our sins away. Let that be true of today.",
        "Was there a time you chose comfort over kindness today? Say sorry, then rest.",
        "Did you speak about someone in a way you wouldn't want them to hear? Bring it to God.",
        "Tell God about one worry you held onto instead of handing it to Him.",
        "Was there a promise you didn't keep today? Ask God for grace to try again.",
        "Where did pride show up today? Hand it over.",
        "Is there anything you've kept from God? Tonight you can bring it into the light.",
        "Tell God one way you'd like to love better tomorrow.",
        "Breathe in His forgiveness. Breathe out what you're sorry for.",
        "You don't have to earn His mercy tonight. Just receive it.",
    ]

    static let ask = [
        "Ask God for what you need most tonight, in plain words.",
        "Who is on your heart right now? Ask God to meet them where they are.",
        "Ask for peace over anything that might keep you awake.",
        "Pray for someone who had a hard day today.",
        "Ask God for wisdom about the decision on your mind.",
        "Pray for your family: their sleep, their health, their hearts.",
        "Ask God to heal what hurts, in you or in someone you love.",
        "Is there a fear you'd like to hand over? Ask God to carry it tonight.",
        "Pray for a friend who feels far from God.",
        "Ask for the strength you'll need tomorrow.",
        "Pray for someone you find hard to love.",
        "Ask God to guard your mind tonight and give you rest.",
        "Pray for those working through the night: nurses, parents, drivers, guards.",
        "Ask God for one thing for the world tonight.",
        "Pray for someone who is grieving.",
        "Ask God to provide for a need you can't meet on your own.",
        "Pray for your church and the people in it.",
        "Ask God to make you more like Jesus, a little more each day.",
        "Pray for anyone who is lonely tonight.",
        "Ask Him to help you put the phone down and rest.",
        "Bring God the request you've been afraid to ask. He loves to hear it.",
        "Ask for a heart that trusts Him with everything you couldn't finish today.",
    ]

    static let tomorrow = [
        "Picture tomorrow morning. Ask God to be there before you are.",
        "What's waiting for you tomorrow? Hand it to God and let Him hold it overnight.",
        "Ask God for one way to love someone tomorrow.",
        "You can lie down in peace and sleep, because He keeps you safe. Rest in that.",
        "Name one thing you're nervous about tomorrow. Give it to God.",
        "Ask God to help you start tomorrow with Him, before the phone.",
        "Tomorrow can worry about itself. Let tonight be for rest.",
        "Ask God to guide your words tomorrow.",
        "What would you like to do differently tomorrow? Ask for His help with it.",
        "Give tomorrow's work to the Lord, and trust Him with how it goes.",
        "Ask God to lead you to someone who needs encouragement tomorrow.",
        "Let go of what you didn't finish today. It can wait until morning.",
        "Ask for joy tomorrow, and eyes to see His gifts.",
        "Give God your plans for tomorrow. Hold them with open hands.",
        "Ask God to watch over the people you love while you sleep.",
        "The One who keeps you never sleeps, so you can.",
        "Ask God to make tomorrow a day of praying first.",
        "Think of one small step of faith for tomorrow. Ask Him for courage.",
        "Say goodnight to God, the way you would to someone you love.",
        "Ask Him to speak to you in the morning, and to help you listen.",
        "Rest now. His mercies will be new in the morning.",
        "End with this: into Your hands, Lord, I give this night and tomorrow.",
    ]
}
