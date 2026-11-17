import SwiftData
import SwiftUI

/// Favorites from Scroll the Word: every saved verse, or one board ("Morning", "Hard days", your own).
struct SavedVersesView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \SavedVerse.savedAt, order: .reverse) private var saved: [SavedVerse]
    @State private var shareCard: ShareCardKind?
    @State private var tab = Tab.all
    @State private var openBoard: WordBoard?

    enum Tab: Hashable { case all, boards }

    var body: some View {
        ZStack {
            AppBackground()
            VStack(spacing: 0) {
                Picker("Show", selection: $tab) {
                    Text("All").tag(Tab.all).accessibilityIdentifier("saved.tab.all")
                    Text("Boards").tag(Tab.boards).accessibilityIdentifier("saved.tab.boards")
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, Spacing.page)
                .padding(.vertical, 10)
                .accessibilityIdentifier("saved.tabs")
                switch tab {
                case .all: allList
                case .boards: boardList
                }
            }
        }
        .navigationTitle("Saved verses")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        .sheet(item: $shareCard) { kind in ShareCardSheet(kind: kind).environment(model) }
        .navigationDestination(item: $openBoard) { board in BoardDetailView(boardID: board.id) }
        .onAppear { model.wordProgress.ensureBoards() }
    }

    @ViewBuilder
    private var allList: some View {
        if saved.isEmpty {
            EmptyState(title: "No saved verses yet", message: "Double-tap a verse in Scroll the Word to keep it here.", systemImage: "heart.fill")
                .frame(maxHeight: .infinity)
        } else {
            List {
                ForEach(saved) { entry in
                    SavedVerseRow(entry: entry, boards: model.wordProgress.boards(containing: entry.ref),
                                  onShare: { shareCard = .verse(entry.verse) }, onPray: { pray(entry.verse) })
                        .listRowBackground(Theme.surface)
                }
                .onDelete { offsets in
                    for index in offsets {
                        model.wordProgress.removeEverywhere(ref: saved[index].ref)
                        context.delete(saved[index])
                    }
                    try? context.save()
                    model.savedVersesChanged()
                }
            }
            .scrollContentBackground(.hidden)
        }
    }

    private var boardList: some View {
        List {
            Section {
                ForEach(model.wordProgress.boards) { board in
                    Button { openBoard = board } label: {
                        HStack(spacing: 12) {
                            Text(board.emoji).font(.title2)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(board.name).font(.akHeadline).foregroundStyle(Theme.textPrimary)
                                Text(board.refs.count == 1 ? "1 verse" : "\(board.refs.count) verses")
                                    .font(.akFootnote).foregroundStyle(Theme.textSecondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(Theme.textSecondary)
                        }
                        .frame(minHeight: 48)
                        .contentShape(Rectangle())
                    }
                    .accessibilityIdentifier("saved.board.\(board.name)")
                    .listRowBackground(Theme.surface)
                }
                .onDelete { offsets in
                    let ids = offsets.map { model.wordProgress.boards[$0].id }
                    for id in ids { model.wordProgress.deleteBoard(id) }
                }
            } footer: {
                Text("Long-press the heart on any verse, or tap “Add to a board” after you save one.")
            }
        }
        .scrollContentBackground(.hidden)
    }

    private func pray(_ verse: Verse) {
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            model.startPrayer(style: .verse, source: .manual, verse: verse)
        }
    }
}

/// One saved verse: text, reference, its boards, share and pray.
private struct SavedVerseRow: View {
    let entry: SavedVerse
    var boards: [WordBoard] = []
    var onShare: () -> Void
    var onPray: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(entry.text).font(.akVerse).foregroundStyle(Theme.textPrimary)
            HStack {
                Text(entry.ref).font(.system(.subheadline, design: .serif, weight: .semibold)).foregroundStyle(Theme.goldText)
                if !boards.isEmpty {
                    Text(boards.map(\.emoji).joined())
                        .font(.footnote)
                        .accessibilityLabel("On " + boards.map(\.name).joined(separator: ", "))
                }
                Spacer()
                Button(action: onShare) { Image(systemName: "square.and.arrow.up") }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Share")
                Button(action: onPray) { Image(systemName: "hands.and.sparkles.fill") }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Pray this")
            }
            .foregroundStyle(Theme.goldText)
        }
        .padding(.vertical, 6)
    }
}

/// One board's verses, newest first.
private struct BoardDetailView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \SavedVerse.savedAt, order: .reverse) private var saved: [SavedVerse]
    let boardID: String
    @State private var shareCard: ShareCardKind?

    private var board: WordBoard? { model.wordProgress.boards.first { $0.id == boardID } }

    var body: some View {
        let refs = board?.refs ?? []
        let byRef = Dictionary(saved.map { ($0.ref, $0) }, uniquingKeysWith: { first, _ in first })
        let entries = refs.compactMap { byRef[$0] }
        ZStack {
            AppBackground()
            if entries.isEmpty {
                EmptyState(title: "Nothing here yet", message: "Long-press the heart on a verse to add it to \(board?.name ?? "this board").",
                           systemImage: "rectangle.stack.fill")
            } else {
                List {
                    ForEach(entries) { entry in
                        SavedVerseRow(entry: entry, onShare: { shareCard = .verse(entry.verse) }, onPray: {
                            let verse = entry.verse
                            model.startPrayer(style: .verse, source: .manual, verse: verse)
                        })
                        .listRowBackground(Theme.surface)
                    }
                    .onDelete { offsets in
                        for index in offsets { model.wordProgress.remove(ref: entries[index].ref, fromBoard: boardID) }
                    }
                }
                .scrollContentBackground(.hidden)
            }
        }
        .navigationTitle(board.map { "\($0.emoji) \($0.name)" } ?? "Board")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $shareCard) { kind in ShareCardSheet(kind: kind).environment(model) }
    }
}

/// "Save to a board": pick one or more boards for a verse, or start a new one. Saving to a board also saves the verse.
struct SaveToBoardSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let verse: Verse
    /// Makes sure the verse is saved (a board holds saved verses).
    var onSave: () -> Void = {}
    @State private var newName = ""
    @State private var newEmoji = "✨"
    @State private var creating = false
    @FocusState private var nameFocused: Bool
    private static let emojis = ["✨", "🙏", "🕊️", "🌿", "🔥", "💛", "⛰️", "🌊", "🌙", "📖"]

    var body: some View {
        ScrollViewReader { proxy in
            form
                .onChange(of: creating) { _, now in
                    guard now else { return }
                    // The name field opens below the boards: bring it on screen and put the cursor in it.
                    DispatchQueue.main.async {
                        withAnimation { proxy.scrollTo(Self.nameRow, anchor: .center) }
                        nameFocused = true
                    }
                }
        }
        .tint(Palette.gold)
        .navigationTitle("Save to a board")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() }.fontWeight(.semibold) } }
        .onAppear { model.wordProgress.ensureBoards() }
    }

    private static let nameRow = "word.board.nameRow"

    private var form: some View {
        Form {
            Section {
                Text(verse.ref)
                    .font(.system(.headline, design: .serif, weight: .semibold))
                    .foregroundStyle(Theme.goldText)
                    .accessibilityIdentifier("word.board.verse")
            }
            Section("Boards") {
                ForEach(model.wordProgress.boards) { board in
                    let on = board.refs.contains(verse.ref)
                    Button { toggle(board, on: on) } label: {
                        HStack(spacing: 12) {
                            Text(board.emoji).font(.title3)
                            Text(board.name).foregroundStyle(Theme.textPrimary)
                            Spacer()
                            Image(systemName: on ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(on ? Palette.gold : Theme.textSecondary)
                                .font(.title3)
                        }
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                    }
                    .accessibilityValue(on ? "Added" : "")
                    .accessibilityIdentifier("word.board.\(board.name)")
                }
            }
            Section {
                if creating {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Self.emojis, id: \.self) { emoji in
                                Button { newEmoji = emoji } label: {
                                    Text(emoji)
                                        .font(.title2)
                                        .frame(width: 44, height: 44)
                                        .background(Circle().fill(newEmoji == emoji ? Palette.gold.opacity(0.3) : .clear))
                                }
                                .buttonStyle(.borderless)
                                .accessibilityLabel(emoji)
                            }
                        }
                    }
                    TextField("Board name", text: $newName)
                        .focused($nameFocused)
                        .id(Self.nameRow)
                        .textInputAutocapitalization(.sentences)
                        .submitLabel(.done)
                        .onSubmit(create)
                        .onChange(of: newName) { _, value in
                            if value.count > WordBoard.maxNameLength { newName = String(value.prefix(WordBoard.maxNameLength)) }
                        }
                        .accessibilityIdentifier("word.board.newName")
                    Button("Create and add", action: create)
                        .fontWeight(.semibold)
                        .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
                        .accessibilityIdentifier("word.board.create")
                } else {
                    Button { creating = true } label: { Label("New board", systemImage: "plus") }
                        .accessibilityIdentifier("word.board.new")
                }
            }
        }
    }

    private func toggle(_ board: WordBoard, on: Bool) {
        Haptics.selection()
        if on {
            model.wordProgress.remove(ref: verse.ref, fromBoard: board.id)
        } else {
            onSave()
            _ = model.wordProgress.add(ref: verse.ref, toBoard: board.id, today: DayKey.today())
        }
    }

    private func create() {
        let name = newName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty, let board = model.wordProgress.addBoard(name: name, emoji: newEmoji) else { return }
        onSave()
        _ = model.wordProgress.add(ref: verse.ref, toBoard: board.id, today: DayKey.today())
        Haptics.success()
        newName = ""
        nameFocused = false
        creating = false
    }
}

/// Today's goal, the goal streak, the level, totals and badges. Set the daily goal here. No guilt: a missed day
/// just starts a new streak.
struct WordProgressSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let progress = model.wordProgress
        let today = DayKey.today()
        let read = progress.readOn(today.string)
        let goal = model.settings.wordGoal
        let streak = progress.streak(today: today)
        let level = progress.level
        ScrollView {
            VStack(spacing: 22) {
                ZStack {
                    ProgressRing(progress: Double(read) / Double(max(1, goal)), lineWidth: 14, track: Palette.cream.opacity(0.12))
                    VStack(spacing: 2) {
                        Text("\(read)")
                            .font(.system(size: 44, weight: .bold, design: .rounded))
                            .foregroundStyle(Palette.cream)
                            .monospacedDigit()
                        Text("of \(goal) today").font(.akFootnote).foregroundStyle(Palette.cream.opacity(0.7))
                    }
                }
                .frame(width: 170, height: 170)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(read) of \(goal) verses today")
                .accessibilityIdentifier("word.progress.ring")
                Text(WordProgressCopy.todayLine(read: read, goal: goal))
                    .font(.akCallout)
                    .foregroundStyle(Palette.cream.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier("word.progress.today")

                VStack(alignment: .leading, spacing: 10) {
                    Text("Daily goal").akOverline(color: Palette.warmGold)
                    HStack(spacing: 8) {
                        ForEach(WordProgress.goalOptions, id: \.self) { option in
                            Button {
                                Haptics.selection()
                                model.updateSettings { $0.wordGoal = option }
                            } label: {
                                Text("\(option)")
                                    .font(.akHeadline)
                                    .monospacedDigit()
                                    .foregroundStyle(option == goal ? Palette.midnight : Palette.cream)
                                    .frame(maxWidth: .infinity, minHeight: 44)
                                    .background {
                                        if option == goal { Capsule().fill(Palette.goldButton) } else { Capsule().fill(Color.white.opacity(0.08)) }
                                    }
                            }
                            .accessibilityLabel("\(option) verses a day")
                            .accessibilityAddTraits(option == goal ? .isSelected : [])
                            .accessibilityIdentifier("word.goal.option.\(option)")
                        }
                    }
                }

                HStack(spacing: 12) {
                    statTile(streak > 0 ? "\(streak)" : "–", label: "day streak", symbol: "flame.fill",
                             id: "word.progress.streak")
                    statTile("\(progress.totalRead)", label: "verses read", symbol: "book.fill", id: "word.progress.total")
                    statTile("\(progress.goalDays.count)", label: "goal days", symbol: "checkmark.seal.fill", id: "word.progress.days")
                }

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Level \(level.number) · \(level.name)")
                            .font(.system(.title3, design: .serif, weight: .bold))
                            .foregroundStyle(Palette.cream)
                        Spacer()
                        if let next = level.next {
                            Text("\(max(0, next - progress.totalRead)) to \(WordLevel.for(read: next).name)")
                                .font(.akFootnote).foregroundStyle(Palette.cream.opacity(0.7))
                        }
                    }
                    ProgressView(value: level.progress(read: progress.totalRead))
                        .tint(Palette.gold)
                        .accessibilityLabel("Level progress")
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("word.progress.level")

                VStack(alignment: .leading, spacing: 12) {
                    Text("Badges").akOverline(color: Palette.warmGold)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 12)], spacing: 12) {
                        ForEach(WordBadge.allCases, id: \.self) { badge in
                            let earned = progress.badges.contains(badge)
                            VStack(spacing: 6) {
                                Image(systemName: badge.symbol)
                                    .font(.system(size: 22, weight: .semibold))
                                    .foregroundStyle(earned ? AnyShapeStyle(Palette.goldGradient) : AnyShapeStyle(Palette.cream.opacity(0.3)))
                                    .frame(width: 48, height: 48)
                                    .background(Circle().fill(Color.white.opacity(earned ? 0.12 : 0.05)))
                                Text(badge.title)
                                    .font(.akCaption.weight(.semibold))
                                    .foregroundStyle(Palette.cream.opacity(earned ? 1 : 0.5))
                                    .multilineTextAlignment(.center)
                                    .lineLimit(2)
                            }
                            .frame(maxWidth: .infinity)
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel("\(badge.title). \(badge.detail)")
                            .accessibilityValue(earned ? "Earned" : "Not yet")
                            .accessibilityIdentifier("word.badge.\(badge.rawValue)")
                        }
                    }
                }
                Text("Your reading stays on this iPhone.")
                    .font(.akCaption)
                    .foregroundStyle(Palette.cream.opacity(0.5))
            }
            .padding(Spacing.page)
        }
        .background(Palette.midnightDeep.ignoresSafeArea())
        .environment(\.colorScheme, .dark)
        .navigationTitle("Your reading")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() }.fontWeight(.semibold) } }
    }

    private func statTile(_ value: String, label: String, symbol: String, id: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: symbol).foregroundStyle(Palette.flameGradient)
            Text(value)
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundStyle(Palette.cream)
                .monospacedDigit()
            Text(label).font(.akCaption).foregroundStyle(Palette.cream.opacity(0.7))
        }
        .frame(maxWidth: .infinity, minHeight: 96)
        .background(RoundedRectangle(cornerRadius: 18).fill(Color.white.opacity(0.06)))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(id)
    }
}

/// Words on the progress sheet. Encouraging, never shaming (unit-tested).
enum WordProgressCopy {
    static func todayLine(read: Int, goal: Int) -> String {
        if read == 0 { return "A fresh start. One verse is a good place to begin." }
        if read >= goal { return "Goal done 🙏 Keep going, or take what you read into prayer." }
        let left = goal - read
        return left == 1 ? "1 more verse to today's goal." : "\(left) more verses to today's goal."
    }
}
