import SwiftData
import SwiftUI

/// Prayer journal: searchable entries grouped by month, linked to people and requests.
struct JournalView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.modelContext) private var context
    @Query(sort: \JournalEntry.createdAt, order: .reverse) private var entries: [JournalEntry]
    @State private var search = ""
    @State private var editing: JournalEntry?
    @State private var composing = false

    private var filtered: [JournalEntry] {
        let q = search.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return entries }
        return entries.filter {
            $0.text.lowercased().contains(q) || $0.personName.lowercased().contains(q)
                || $0.requestText.lowercased().contains(q) || $0.verseRef.lowercased().contains(q)
        }
    }

    private var grouped: [(String, [JournalEntry])] {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("MMMM yyyy")
        var order: [String] = []
        var map: [String: [JournalEntry]] = [:]
        for entry in filtered {
            let key = formatter.string(from: entry.createdAt)
            if map[key] == nil { order.append(key) }
            map[key, default: []].append(entry)
        }
        return order.map { ($0, map[$0] ?? []) }
    }

    var body: some View {
        ZStack {
            AppBackground()
            if entries.isEmpty {
                EmptyState(title: model.content.copy.string("emptyStates.journal.title", default: "Your prayer journal starts here"),
                           message: model.content.copy.string("emptyStates.journal.message", default: "After you pray, jot down a line about what's on your heart."),
                           systemImage: "book.closed.fill",
                           actionTitle: model.content.copy.string("emptyStates.journal.action", default: "Write an entry")) { composing = true }
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 14, pinnedViews: []) {
                        ForEach(grouped, id: \.0) { month, items in
                            Text(month).akOverline().padding(.top, 8)
                            ForEach(items) { entry in
                                Button { editing = entry } label: { JournalCard(entry: entry) }
                                    .buttonStyle(PressScaleStyle(scale: 0.99))
                                    .contextMenu {
                                        Button(role: .destructive) {
                                            context.delete(entry)
                                            try? context.save()
                                        } label: { Label("Delete", systemImage: "trash") }
                                    }
                            }
                        }
                        if filtered.isEmpty {
                            Text("Nothing matches \"\(search)\".")
                                .font(.akCallout).foregroundStyle(Theme.textSecondary)
                                .frame(maxWidth: .infinity).padding(.top, 40)
                        }
                    }
                    .padding(.horizontal, Spacing.page)
                    .padding(.bottom, 32)
                }
            }
        }
        .navigationTitle("Journal")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $search, prompt: "Search your journal")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { composing = true } label: { Image(systemName: "square.and.pencil") }
                    .tint(Theme.goldIcon)
                    .accessibilityLabel("New entry")
                    .accessibilityIdentifier("journal.new")
            }
        }
        .sheet(isPresented: $composing) { JournalEditorSheet(entry: nil).environment(model) }
        .sheet(item: $editing) { entry in JournalEditorSheet(entry: entry).environment(model) }
    }
}

struct JournalCard: View {
    let entry: JournalEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(entry.createdAt.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
                    .font(.akCaption).foregroundStyle(Theme.textTertiary)
                Spacer()
                if let style = entry.style {
                    Image(systemName: style.symbol).font(.caption).foregroundStyle(Theme.goldIcon)
                        .accessibilityLabel(style.title)
                }
            }
            Text(entry.text)
                .font(.system(.body, design: .serif))
                .foregroundStyle(Theme.textPrimary)
                .multilineTextAlignment(.leading)
                .lineLimit(6)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                if !entry.personName.isEmpty { Chip(text: entry.personName, systemImage: "person.fill") }
                if !entry.verseRef.isEmpty { Chip(text: entry.verseRef, systemImage: "book.fill", tint: Theme.sageText) }
                if !entry.requestText.isEmpty { Chip(text: entry.requestText, systemImage: "heart.fill", tint: Theme.roseText) }
            }
        }
        .akCard(padding: 16, cornerRadius: 20)
    }
}

struct JournalEditorSheet: View {
    let entry: JournalEntry?
    @Environment(AppModel.self) private var model
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Person.name) private var people: [Person]
    @State private var text = ""
    @State private var personID: UUID?
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                VStack(alignment: .leading, spacing: 14) {
                    Text((entry?.createdAt ?? Date()).formatted(date: .complete, time: .omitted)).akOverline()
                    TextEditor(text: $text)
                        .font(.system(.body, design: .serif))
                        .scrollContentBackground(.hidden)
                        .focused($focused)
                        .frame(minHeight: 220)
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.surface))
                        .overlay(alignment: .topLeading) {
                            if text.isEmpty {
                                Text("What's on your heart today?")
                                    .font(.system(.body, design: .serif))
                                    .foregroundStyle(Theme.textTertiary)
                                    .padding(.horizontal, 17)
                                    .padding(.vertical, 20)
                                    .allowsHitTesting(false)
                            }
                        }
                        .accessibilityIdentifier("journal.text")
                    if !people.isEmpty {
                        Text("About someone? (optional)").font(.akSubheadlineSemibold).foregroundStyle(Theme.textSecondary)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(people) { person in
                                    Button {
                                        personID = personID == person.id ? nil : person.id
                                        Haptics.selection()
                                    } label: {
                                        Chip(text: person.firstName, isSelected: personID == person.id)
                                    }
                                    .buttonStyle(PressScaleStyle())
                                }
                            }
                        }
                    }
                    Spacer()
                }
                .padding(Spacing.page)
            }
            .navigationTitle(entry == nil ? "New entry" : "Journal entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .fontWeight(.semibold)
                        .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                if let entry {
                    text = entry.text
                    personID = entry.personID
                } else {
                    focused = true
                }
            }
        }
    }

    private func save() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let person = people.first { $0.id == personID }
        if let entry {
            entry.text = trimmed
            entry.personID = person?.id
            entry.personName = person?.name ?? ""
        } else {
            context.insert(JournalEntry(text: trimmed, person: person))
        }
        try? context.save()
        Haptics.success()
        dismiss()
    }
}
