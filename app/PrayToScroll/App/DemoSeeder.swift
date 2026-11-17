#if DEBUG
// Debug builds only: demo data / mock circles for UI tests and screenshots. Not in the Release binary.
import Foundation
import SwiftData

/// Seeds the `-demo` launch (UI tests + App Store screenshots). Never runs for real users:
/// demo data lives in memory and in its own defaults domain.
enum DemoSeeder {
    /// Deterministic generator so screenshots are identical run to run.
    struct SeededGenerator: RandomNumberGenerator {
        var state: UInt64
        mutating func next() -> UInt64 {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return state
        }
    }

    static func seedDefaults(store: SharedStore, options: LaunchOptions) {
        let calendar = Calendar.current
        let now = Date()
        var settings = AppSettings()
        settings.firstName = "Grace"
        settings.unlockStyle = .guided
        settings.guidedSeconds = 120
        settings.unlockMode = .window
        settings.unlockWindowMinutes = 15
        settings.gatedAppIDs = ["instagram", "tiktok", "youtube", "x"]
        #if STRICT_LOCK
        // The Strict Lock build's demo locks with Screen Time (DemoLock stands in for Apple's shields); first run
        // starts unchosen.
        settings.lockMethod = options.showOnboarding || options.shortcutsGate ? .shortcuts : .screenTime
        #else
        settings.lockMethod = .shortcuts
        #endif
        settings.hasOnboarded = !options.showOnboarding
        settings.scrollHoursPerDay = 3.5
        settings.reminders.dailyEnabled = true
        settings.reminders.dailyHour = 7
        settings.reminders.dailyMinute = 30
        settings.reminders.morningVerseEnabled = true
        settings.circleDisplayEmoji = "🕊️"
        if options.showOnboarding {
            settings.firstName = ""
            settings.gatedAppIDs = []
        }
        let content = ContentStore.shared
        let fast = content.challenges.first { $0.days == 40 } ?? content.challenges.first
        let fresh = content.challenges.first { $0.days == 7 }
        if let fast {
            settings.activeChallenges = [ActiveChallenge(id: fast.id, startedAt: calendar.date(byAdding: .day, value: -12, to: now) ?? now)]
        }
        if let fresh { settings.completedChallengeIDs = [fresh.id] }
        store.settings = settings

        let hour: TimeInterval = 3600
        store.gateFiredDates = [
            "instagram": now.addingTimeInterval(-2 * hour),
            "tiktok": now.addingTimeInterval(-5 * hour),
            "youtube": now.addingTimeInterval(-20 * hour),
            "x": now.addingTimeInterval(-0.6 * hour),
        ]
        store.setupMarked = store.gateFiredDates
        store.gateTriggers = 61
        store.emergencyUses = 2
        store.unlockedUntil = nil
        store.dailyKeyUntil = nil
        store.pausedUntil = nil
        store.emergencyLastUsed = calendar.date(byAdding: .day, value: -6, to: now)
        let today = DayKey(now, calendar: calendar)
        store.frozenDays = [today.adding(days: -9, calendar: calendar)]
        store.promptBags = [:]

        // Scroll the Word: four goal days in a row before today (today still open, nothing read yet), Level 5.
        var word = WordProgress()
        for back in 1...12 {
            let day = today.adding(days: -back, calendar: calendar).string
            let read = back <= 4 ? 10 + back : (back == 5 || back.isMultiple(of: 3) ? 4 : 11)
            word.readByDay[day] = read
            if read >= WordProgress.defaultGoal { word.goalDays.append(day) }
        }
        word.goalDays.sort()
        word.totalRead = 142
        word.themesRead = ["peace", "hope", "anxiety", "strength", "love", "rest", "gratitude", "courage", "purpose"]
        word.finishPlayed = 6
        word.finishRight = 4
        word.whoPlayed = 3
        word.whoRight = 2
        word.badges = [.firstSave, .firstGoal, .streak3, .read100, .firstBoard]
        word.affinity = ["peace": 2.4, "hope": 1.6, "anxiety": 1.1, "focus": -0.6]
        word.ensureBoards()
        store.wordProgressData = try? JSONEncoder().encode(word)
    }

    static func seedData(context: ModelContext, store: SharedStore, withPeople: Bool = true) {
        let calendar = Calendar.current
        let now = Date()
        let today = DayKey(now, calendar: calendar)
        var rng = SeededGenerator(state: 2026_11_16)
        let settings = store.settings
        guard settings.hasOnboarded else { return }

        func daysAgo(_ n: Int, hour: Int = 8, minute: Int = 0) -> Date {
            let day = today.adding(days: -n, calendar: calendar)
            return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day.noonDate(in: calendar)) ?? now
        }

        // People + requests
        let sarah = Person(name: "Sarah Mitchell", relationship: "Friend", emoji: "", colorIndex: 2)
        let dad = Person(name: "Dad", relationship: "Family", emoji: "👨🏻‍🦳", colorIndex: 0)
        let emma = Person(name: "Emma", relationship: "Sister", emoji: "🌷", colorIndex: 4)
        let james = Person(name: "James Carter", relationship: "Small group", emoji: "", colorIndex: 3)
        let olivia = Person(name: "Olivia Lee", relationship: "Coworker", emoji: "", colorIndex: 1)
        let pastor = Person(name: "Pastor Dan", relationship: "Church", emoji: "⛪️", colorIndex: 5)
        let luke = Person(name: "Luke Romero", relationship: "Neighbor", emoji: "", colorIndex: 0)
        sarah.phone = "(555) 010-0104"
        dad.phone = "(555) 010-0100"
        let people = [sarah, dad, emma, james, olivia, pastor, luke]
        let lastPrayed: [Int] = [11, 1, 2, 4, 6, 8, 3]
        let counts: [Int] = [9, 23, 17, 8, 6, 5, 4]
        for (index, person) in people.enumerated() {
            person.createdAt = daysAgo(60 - index * 3)
            person.lastPrayedAt = daysAgo(lastPrayed[index], hour: 19)
            person.prayerCount = counts[index]
            context.insert(person)
        }

        func request(_ text: String, _ person: Person, created: Int, answered: Int? = nil, note: String = "") {
            let r = PrayerRequest(text: text, person: person, createdAt: daysAgo(created))
            r.timesPrayed = max(1, created / 3)
            if let answered {
                r.isAnswered = true
                r.answeredAt = daysAgo(answered, hour: 18)
                r.answerNote = note
            }
            context.insert(r)
            r.person = person
        }

        request("Peace and clarity before her job interview on Thursday", sarah, created: 6)
        request("Her mom's surgery", sarah, created: 31, answered: 9, note: "Surgery went perfectly. Home in two days.")
        request("Healing for his back so he can golf again", dad, created: 24)
        request("Wisdom about selling the business", dad, created: 58, answered: 15, note: "Found a buyer who'll keep the whole team.")
        request("A healthy pregnancy and an easy delivery", emma, created: 40)
        request("Finding an apartment near the hospital", emma, created: 52, answered: 33, note: "Signed the lease, two blocks away!")
        request("Peace about the move to Denver", james, created: 12)
        request("Her son's first week at a new school", olivia, created: 20, answered: 13, note: "He made two friends on day one.")
        request("Strength for the Christmas season", pastor, created: 5)
        request("Getting back on his feet after the layoff", luke, created: 18)
        request("A job that fits", luke, created: 44, answered: 26, note: "Starts at the hardware store Monday.")

        // Sessions: a 13-day streak (yesterday back to 14 days ago, with a free freeze 9 days ago),
        // plus three months of honest history before it.
        let styles: [UnlockStyle] = [.guided, .quick, .verse, .forSomeone, .guided, .quick]
        let gateApps = ["instagram", "tiktok", "youtube", "x"]
        var streakDays: [Int] = Array(1...14).filter { $0 != 9 }
        let history = (16...95).filter { _ in Double(rng.next() % 1000) / 1000 < 0.66 }
        streakDays += history
        for dayOffset in streakDays {
            let sessionsToday = 1 + Int(rng.next() % 3)
            for s in 0..<sessionsToday {
                let style = styles[Int(rng.next() % UInt64(styles.count))]
                let start = daysAgo(dayOffset, hour: [7, 12, 18, 21][s % 4], minute: Int(rng.next() % 50))
                let length: Double
                switch style {
                case .quick: length = 35
                case .guided: length = 125
                case .verse: length = 70
                case .forSomeone: length = 55
                case .readVerse: length = 25
                case .devotional: length = 80
                }
                let isGate = rng.next() % 3 != 0
                let session = PrayerSession(startedAt: start, completedAt: start.addingTimeInterval(length), style: style,
                                            source: isGate ? .gate : .manual,
                                            gatedAppID: isGate ? gateApps[Int(rng.next() % UInt64(gateApps.count))] : "")
                if style == .forSomeone {
                    let person = people[Int(rng.next() % UInt64(people.count))]
                    session.personID = person.id
                    session.personName = person.name
                }
                context.insert(session)
            }
        }

        // Journal
        let entries: [(Int, String, Person?, UnlockStyle?)] = [
            (1, "Prayed before opening Instagram and realized I didn't actually want to scroll. I wanted to rest. Went for a walk instead.", nil, .guided),
            (2, "Emma sent a photo from the ultrasound. Thank You, Lord, for this little life.", emma, .forSomeone),
            (3, "Hard day at work. Psalm 46:10 stopped me in my tracks: be still.", nil, .verse),
            (5, "Texted Sarah that I prayed for her. She called me crying, in a good way. Her interview is Thursday.", sarah, .forSomeone),
            (8, "Dad sounded tired on the phone. Asking for healing and patience for both of us.", dad, .forSomeone),
            (12, "Started the 40-day fast from mindless scrolling. Day one felt strange. Grateful anyway.", nil, .quick),
            (15, "The business sold. Dad kept every single employee. Answered prayer.", dad, nil),
        ]
        for entry in entries {
            context.insert(JournalEntry(text: entry.1, createdAt: daysAgo(entry.0, hour: 21, minute: 12),
                                        person: entry.2, style: entry.3))
        }
        // A few verses saved from Scroll the Word.
        let verses = VerseProvider.shared.verses
        if !verses.isEmpty {
            let todayIndex = today.dayOfYear(calendar: calendar)
            for offset in [3, 11, 19, 27, 34, 46, 58, 71, 89] {
                let saved = SavedVerse(verse: verses[(todayIndex + offset * 7) % verses.count])
                saved.savedAt = daysAgo(offset % 30, hour: 22)
                context.insert(saved)
            }
            // Two of them on the "Morning" board.
            if let data = store.wordProgressData, var word = try? JSONDecoder().decode(WordProgress.self, from: data),
               let morning = word.boards.first {
                for offset in [3, 11] {
                    _ = word.add(ref: verses[(todayIndex + offset * 7) % verses.count].ref, toBoard: morning.id, today: today)
                }
                store.wordProgressData = try? JSONEncoder().encode(word)
            }
        }
        if !withPeople {
            for person in people { context.delete(person) }   // requests go with them (cascade)
        }
        try? context.save()

        // Milestones the history has earned.
        let prayed = Set(streakDays.map { today.adding(days: -$0, calendar: calendar) })
        let longest = StreakEngine.longestChain(prayed: prayed, frozen: store.frozenDays, calendar: calendar)
        var updated = store.settings
        updated.awardedMilestones = MilestoneEngine.milestones.filter { $0 <= longest }
        store.settings = updated
    }
}
#endif
