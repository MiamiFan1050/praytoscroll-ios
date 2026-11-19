import SwiftUI

/// Learn's colors: red letter for Jesus' words (warm enough to read on the photo backdrops).
enum LearnPalette {
    static let redLetter = Color(hex: 0xFFA396)
    static let redLetterDeep = Color(hex: 0xE0675A)
}

/// "Jesus said": his words in red letter, the reference, and who he said them to.
struct JesusSaidCardContent: View {
    let saying: JesusSaying
    var textScale: Double = 1
    var onPray: () -> Void
    @ScaledMetric(relativeTo: .title) private var size: CGFloat = 30

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label("Jesus said", systemImage: "quote.opening")
                .font(.akOverline)
                .tracking(1.4)
                .textCase(.uppercase)
                .foregroundStyle(LearnPalette.redLetter)
            VStack(alignment: .leading, spacing: 16) {
                Text("\u{201C}\(saying.quote)\u{201D}")
                    .font(.system(size: (saying.quote.count > 140 ? size * 0.82 : size) * textScale, weight: .regular, design: .serif))
                    .foregroundStyle(LearnPalette.redLetter)
                    .lineSpacing(6)
                    .shadow(color: .black.opacity(0.5), radius: 8, y: 2)
                    .minimumScaleFactor(0.5)
                    .fixedSize(horizontal: false, vertical: true)
                Text(saying.ref)
                    .font(.system(.title3, design: .serif, weight: .semibold))
                    .foregroundStyle(Palette.warmGold)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Jesus said: \(saying.quote). \(saying.ref)")
            .accessibilityIdentifier("word.jesus")
            HStack(alignment: .top, spacing: 10) {
                Capsule().fill(LearnPalette.redLetter.opacity(0.7)).frame(width: 3)
                Text(saying.context)
                    .font(.system(size: 17 * min(textScale, 1.3), weight: .medium, design: .rounded))
                    .foregroundStyle(Palette.cream.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityElement(children: .combine)
            FeedGoldButton(title: "Pray about it", symbol: "hands.and.sparkles.fill", id: "word.jesus.pray", action: onPray)
            Text("World English Bible")
                .font(.akCaption)
                .foregroundStyle(Palette.cream.opacity(0.5))
                .accessibilityHidden(true)
        }
    }
}

/// "Where and when": the moment, its place and its era, in plain words.
struct PlaceCardContent: View {
    let place: PlaceCard
    var textScale: Double = 1
    @ScaledMetric(relativeTo: .title) private var size: CGFloat = 30

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Where and when").akOverline(color: Palette.warmGold)
            Text(place.title)
                .font(.system(size: size * textScale, weight: .bold, design: .serif))
                .foregroundStyle(Palette.cream)
                .shadow(color: .black.opacity(0.45), radius: 8, y: 2)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel("Where and when: \(place.title). \(place.place). \(place.when). \(place.ref)")
                .accessibilityIdentifier("word.place")
            VStack(alignment: .leading, spacing: 12) {
                row("mappin.and.ellipse", place.place)
                row("hourglass", place.when)
            }
            .accessibilityHidden(true)
            Text(place.text)
                .font(.system(size: 18 * min(textScale, 1.3), weight: .regular, design: .serif))
                .foregroundStyle(Palette.cream.opacity(0.9))
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
            Text(place.ref)
                .font(.system(.headline, design: .serif, weight: .semibold))
                .foregroundStyle(Palette.warmGold)
        }
    }

    private func row(_ symbol: String, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Palette.warmGold)
                .frame(width: 22)
            Text(text)
                .font(.system(size: 17 * min(textScale, 1.3), weight: .semibold, design: .rounded))
                .foregroundStyle(Palette.cream)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.ultraThinMaterial))
    }
}

/// One part of a series. The next part comes up later in the feed: the teaser says so.
struct SeriesCardContent: View {
    let part: FeedSeriesPart
    var textScale: Double = 1
    @ScaledMetric(relativeTo: .title) private var size: CGFloat = 26

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 8) {
                Text(part.title).akOverline(color: Palette.warmGold)
                Text("\(part.index + 1) of \(part.count)")
                    .font(.akCaption.weight(.bold))
                    .foregroundStyle(Palette.midnight)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Palette.goldButton))
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(part.title), part \(part.index + 1) of \(part.count)")
            SeriesDots(index: part.index, count: part.count)
            Text(part.part.text)
                .font(.system(size: size * textScale, weight: .regular, design: .serif))
                .foregroundStyle(Palette.cream)
                .lineSpacing(6)
                .shadow(color: .black.opacity(0.45), radius: 8, y: 2)
                .minimumScaleFactor(0.6)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel("\(part.title), part \(part.index + 1) of \(part.count): \(part.part.text). \(part.part.ref)")
                .accessibilityIdentifier("word.series")
            Text(part.part.ref)
                .font(.system(.headline, design: .serif, weight: .semibold))
                .foregroundStyle(Palette.warmGold)
            if let next = part.part.next, !part.isLast {
                Label(next, systemImage: "sparkles")
                    .font(.akSubheadlineSemibold)
                    .foregroundStyle(Palette.cream)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(.ultraThinMaterial))
                    .accessibilityLabel("Part \(part.index + 2) comes up later in your feed. \(next)")
                Text("Part \(part.index + 2) comes up later as you scroll.")
                    .font(.akCaption)
                    .foregroundStyle(Palette.cream.opacity(0.6))
                    .accessibilityHidden(true)
            } else {
                Label("Series complete: \(part.title)", systemImage: "checkmark.seal.fill")
                    .font(.akSubheadlineSemibold)
                    .foregroundStyle(Palette.warmGold)
            }
        }
    }
}

/// "1 of 5" as dots.
struct SeriesDots: View {
    let index: Int
    let count: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<max(count, 1), id: \.self) { dot in
                Capsule()
                    .fill(dot <= index ? AnyShapeStyle(Palette.goldButton) : AnyShapeStyle(Palette.cream.opacity(0.25)))
                    .frame(width: dot == index ? 22 : 10, height: 6)
            }
        }
        .accessibilityHidden(true)
    }
}

/// Into Learn from the feed: today's Daily 5 (five empty squares to fill), or the next lesson on your path.
struct LearnNudgeCardContent: View {
    let nudge: LearnNudge
    var onOpen: () -> Void
    @ScaledMetric(relativeTo: .title) private var size: CGFloat = 32

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            switch nudge {
            case .daily5(let number):
                Text("Daily 5 · #\(number)").akOverline(color: Palette.warmGold)
                Text("Five questions. The same five for everyone today.")
                    .font(.system(size: size, weight: .bold, design: .serif))
                    .foregroundStyle(Palette.cream)
                    .shadow(color: .black.opacity(0.45), radius: 8, y: 2)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel("Daily 5 number \(number). Five questions, the same five for everyone today.")
                    .accessibilityIdentifier("word.learn")
                HStack(spacing: 8) {
                    ForEach(0..<Daily5.count, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(Palette.cream.opacity(0.55), lineWidth: 2)
                            .frame(width: 40, height: 40)
                    }
                }
                .accessibilityHidden(true)
                Text("About a minute. Share your score when you’re done.")
                    .font(.akFootnote)
                    .foregroundStyle(Palette.cream.opacity(0.75))
                FeedGoldButton(title: "Play today’s Daily 5", symbol: "square.grid.3x3.fill", id: "word.learn.daily5", action: onOpen)
            case .lesson(_, let title, let pathTitle, let number, let count, let verseRef, let started):
                Text(started ? "Continue your lesson" : "Start learning").akOverline(color: Palette.warmGold)
                Text(title)
                    .font(.system(size: size, weight: .bold, design: .serif))
                    .foregroundStyle(Palette.cream)
                    .shadow(color: .black.opacity(0.45), radius: 8, y: 2)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel("\(started ? "Continue your lesson" : "Start learning"): \(title), lesson \(number) of \(count) in \(pathTitle)" + (verseRef.map { ". \($0)" } ?? ""))
                    .accessibilityIdentifier("word.learn")
                Label("\(pathTitle) · Lesson \(number) of \(count)", systemImage: "map.fill")
                    .font(.akSubheadlineSemibold)
                    .foregroundStyle(Palette.cream.opacity(0.9))
                ProgressView(value: Double(number - 1), total: Double(max(count, 1)))
                    .tint(Palette.gold)
                    .frame(maxWidth: 240)
                    .accessibilityHidden(true)
                Text("About 2 minutes: the story, a key verse and a quick check.")
                    .font(.akFootnote)
                    .foregroundStyle(Palette.cream.opacity(0.75))
                FeedGoldButton(title: started ? "Continue" : "Start lesson", symbol: "play.fill", id: "word.learn.lesson", action: onOpen)
            }
        }
        .padding(.bottom, 40)
    }
}

/// The feed's gold capsule button.
struct FeedGoldButton: View {
    let title: String
    let symbol: String
    let id: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.akHeadline)
                .foregroundStyle(Palette.midnight)
                .padding(.horizontal, 22)
                .frame(minHeight: 50)
                .background(Capsule().fill(Palette.goldButton))
        }
        .buttonStyle(PressScaleStyle())
        .accessibilityIdentifier(id)
    }
}

/// Three right in a row: a small burst of flames and a "3 in a row" line, then it fades.
struct ComboBurst: View {
    let combo: Int
    @State private var fly = false

    var body: some View {
        ZStack {
            ForEach(0..<10, id: \.self) { index in
                let angle = Double(index) / 10 * 2 * .pi
                Image(systemName: "flame.fill")
                    .font(.system(size: index.isMultiple(of: 2) ? 26 : 18))
                    .foregroundStyle(Palette.flameGradient)
                    .offset(x: fly ? cos(angle) * 130 : 0, y: fly ? sin(angle) * 130 : 0)
                    .opacity(fly ? 0 : 1)
                    .scaleEffect(fly ? 0.5 : 1)
            }
            VStack(spacing: 6) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 76))
                    .foregroundStyle(Palette.flameGradient)
                    .shadow(color: Palette.ember.opacity(0.7), radius: 24)
                Text("\(combo) in a row!")
                    .font(.system(.title2, design: .rounded, weight: .heavy))
                    .foregroundStyle(Palette.cream)
                    .shadow(color: .black.opacity(0.6), radius: 6)
            }
            .scaleEffect(fly ? 1 : 0.6)
        }
        .transition(.scale(scale: 0.4).combined(with: .opacity))
        .onAppear { withAnimation(.easeOut(duration: 0.8)) { fly = true } }
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(combo) right in a row")
        .accessibilityIdentifier("learn.combo")
    }
}

/// The combo rule: a burst at every third right answer in a row.
enum QuizCombo {
    static func next(_ combo: Int, right: Bool) -> Int { right ? combo + 1 : 0 }
    static func bursts(_ combo: Int) -> Bool { combo >= 3 && combo % 3 == 0 }

    /// The burst's haptics: a success tap, then a firm one.
    @MainActor static func celebrate() {
        Haptics.success()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { Haptics.ramp(1) }
    }
}
