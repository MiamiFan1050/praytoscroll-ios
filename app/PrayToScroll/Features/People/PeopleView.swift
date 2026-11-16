import SwiftData
import SwiftUI

/// The Prayer List: who you're praying for, longest-waiting first, plus the Answered wall.
struct PeopleView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.modelContext) private var context
    @Query private var people: [Person]
    @Query(filter: #Predicate<PrayerRequest> { $0.isAnswered }) private var answered: [PrayerRequest]
    @State private var showEditor = false
    @State private var search = ""

    var body: some View {
        @Bindable var model = model
        ZStack {
            AppBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Picker("View", selection: $model.peopleShowsAnswered) {
                        Text("Praying for").tag(false)
                        Text("Answered · \(answered.count)").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("people.segment")

                    if model.peopleShowsAnswered {
                        AnsweredWallContent()
                    } else {
                        listContent
                    }
                }
                .padding(.horizontal, Spacing.page)
                .padding(.bottom, 32)
            }
        }
        .navigationTitle(model.peopleShowsAnswered ? "Answered prayers" : "Prayer list")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showEditor = true } label: { Image(systemName: "plus.circle.fill").font(.title3) }
                    .tint(Theme.goldIcon)
                    .accessibilityLabel("Add someone")
                    .accessibilityIdentifier("people.add")
            }
        }
        .searchable(text: $search, placement: .navigationBarDrawer(displayMode: .automatic), prompt: "Search people and requests")
        .sheet(isPresented: $showEditor) {
            PersonEditorSheet(person: nil).environment(model)
        }
        .navigationDestination(for: UUID.self) { id in
            PersonDetailView(personID: id)
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.88), value: model.peopleShowsAnswered)
    }

    private var filtered: [Person] {
        let ranked = PeopleRanking.sorted(people)
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return ranked }
        return ranked.filter { person in
            person.name.lowercased().contains(query)
                || person.relationship.lowercased().contains(query)
                || person.openRequests.contains { $0.text.lowercased().contains(query) }
        }
    }

    @ViewBuilder
    private var listContent: some View {
        if people.isEmpty {
            EmptyState(title: model.content.copy.string("emptyStates.people.title", default: "Who's on your heart?"),
                       message: model.content.copy.string("emptyStates.people.message", default: "Add the people you want to pray for.")
                           .replacingOccurrences(of: "Pray to Scroll", with: AppConstants.appName),
                       systemImage: "person.2.fill",
                       actionTitle: model.content.copy.string("emptyStates.people.action", default: "Add someone")) { showEditor = true }
                .padding(.top, 30)
        } else {
            if let next = filtered.first, search.isEmpty {
                nextUp(next)
            }
            VStack(spacing: 10) {
                ForEach(search.isEmpty ? Array(filtered.dropFirst()) : filtered) { person in
                    NavigationLink(value: person.id) {
                        PersonRow(person: person)
                    }
                    .buttonStyle(PressScaleStyle())
                    .contextMenu {
                        Button { model.startPrayer(style: .forSomeone, source: .manual, personID: person.id) } label: {
                            Label("Pray for \(person.firstName)", systemImage: "hands.and.sparkles.fill")
                        }
                        Button(role: .destructive) {
                            context.delete(person)
                            try? context.save()
                        } label: { Label("Remove", systemImage: "trash") }
                    }
                }
            }
            Text("People who've waited longest for a prayer rise to the top.")
                .font(.akFootnote)
                .foregroundStyle(Theme.textTertiary)
                .frame(maxWidth: .infinity)
                .padding(.top, 4)
        }
    }

    private func nextUp(_ person: Person) -> some View {
        NavigationLink(value: person.id) {
            VStack(alignment: .leading, spacing: 14) {
                Text("Next to pray for").akOverline()
                HStack(spacing: 14) {
                    Avatar(name: person.name, emoji: person.emoji, colorIndex: person.colorIndex, size: 60)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(person.name).font(.akTitle3).foregroundStyle(Theme.textPrimary)
                        Text(PeopleRanking.lastPrayedText(person.lastPrayedAt))
                            .font(.akFootnote).foregroundStyle(Theme.textSecondary)
                    }
                    Spacer(minLength: 0)
                }
                if let request = person.openRequests.first {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "heart.fill").font(.caption).foregroundStyle(Theme.roseText).padding(.top, 3)
                        Text(request.text).font(.akCallout).foregroundStyle(Theme.textPrimary).multilineTextAlignment(.leading)
                    }
                }
                PrimaryButton("Pray for \(person.firstName)", systemImage: "hands.and.sparkles.fill", height: 50) {
                    model.startPrayer(style: .forSomeone, source: .manual, personID: person.id)
                }
                .accessibilityIdentifier("people.prayNext")
            }
            .akCard(highlighted: true)
        }
        .buttonStyle(PressScaleStyle(scale: 0.99))
    }
}

struct PersonRow: View {
    let person: Person

    var body: some View {
        HStack(spacing: 14) {
            Avatar(name: person.name, emoji: person.emoji, colorIndex: person.colorIndex, size: 48)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(person.name).font(.akHeadline).foregroundStyle(Theme.textPrimary)
                    if !person.relationship.isEmpty {
                        Text(person.relationship).font(.akCaption).foregroundStyle(Theme.textTertiary)
                    }
                }
                Text(PeopleRanking.lastPrayedText(person.lastPrayedAt))
                    .font(.akFootnote).foregroundStyle(Theme.textSecondary)
                if let request = person.openRequests.first {
                    Text(request.text).font(.akFootnote).foregroundStyle(Theme.textTertiary).lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            if person.openRequests.count > 0 {
                Text("\(person.openRequests.count)")
                    .font(.akCaption.weight(.bold))
                    .foregroundStyle(Theme.goldText)
                    .frame(minWidth: 26, minHeight: 26)
                    .background(Circle().fill(Palette.gold.opacity(0.15)))
                    .accessibilityLabel("\(person.openRequests.count) open requests")
            }
            Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(Theme.textTertiary)
        }
        .akCard(padding: 14, cornerRadius: 20)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Detail

struct PersonDetailView: View {
    let personID: UUID
    @Environment(AppModel.self) private var model
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var people: [Person]
    @Query(sort: \JournalEntry.createdAt, order: .reverse) private var journal: [JournalEntry]
    @State private var newRequest = ""
    @State private var answering: PrayerRequest?
    @State private var editing = false
    @State private var confirmDelete = false
    @State private var shareCard: ShareCardKind?
    @FocusState private var requestFocused: Bool

    private var person: Person? { people.first { $0.id == personID } }

    var body: some View {
        ZStack {
            AppBackground()
            if let person {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        header(person)
                        PrimaryButton("Pray for \(person.firstName)", systemImage: "hands.and.sparkles.fill") {
                            model.startPrayer(style: .forSomeone, source: .manual, personID: person.id)
                        }
                        .accessibilityIdentifier("person.pray")
                        requests(person)
                        if !person.answeredRequests.isEmpty { answered(person) }
                        notes(person)
                    }
                    .padding(.horizontal, Spacing.page)
                    .padding(.bottom, 40)
                }
                .scrollDismissesKeyboard(.interactively)
            }
        }
        .navigationTitle(person?.firstName ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button { editing = true } label: { Label("Edit", systemImage: "pencil") }
                    Button(role: .destructive) { confirmDelete = true } label: { Label("Remove from list", systemImage: "trash") }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel("More")
            }
        }
        .sheet(isPresented: $editing) {
            PersonEditorSheet(person: person).environment(model)
        }
        .sheet(item: $answering) { request in
            MarkAnsweredSheet(request: request) { note in
                request.isAnswered = true
                request.answeredAt = Date()
                request.answerNote = note
                try? context.save()
                Haptics.success()
                model.toast = "Answered. Praise God!"
                shareCard = .answered(request: request.text, person: person?.firstName ?? "", note: note, days: request.daysToAnswer)
            }
            .presentationDetents([.medium])
        }
        .sheet(item: $shareCard) { kind in
            ShareCardSheet(kind: kind).environment(model)
        }
        .confirmationDialog("Remove \(person?.firstName ?? "") from your prayer list?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Remove", role: .destructive) {
                if let person { context.delete(person) }
                try? context.save()
                dismiss()
            }
        } message: {
            Text("Their requests and answered prayers will be removed too.")
        }
    }

    private func header(_ person: Person) -> some View {
        VStack(spacing: 12) {
            Avatar(name: person.name, emoji: person.emoji, colorIndex: person.colorIndex, size: 96)
                .shadow(color: Theme.shadow, radius: 14, y: 6)
            Text(person.name).font(.akLargeTitle).foregroundStyle(Theme.textPrimary).multilineTextAlignment(.center)
            if !person.relationship.isEmpty {
                Chip(text: person.relationship, tint: Theme.goldText)
            }
            HStack(spacing: 12) {
                StatTile(value: "\(person.prayerCount)", label: person.prayerCount == 1 ? "prayer" : "prayers", systemImage: "hands.and.sparkles.fill")
                StatTile(value: "\(person.answeredRequests.count)", label: "answered", systemImage: "checkmark.seal.fill", tint: Theme.sageText)
            }
            Text(PeopleRanking.lastPrayedText(person.lastPrayedAt))
                .font(.akFootnote)
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    private func requests(_ person: Person) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Praying for")
            ForEach(person.openRequests) { request in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "heart.fill").foregroundStyle(Theme.roseText).padding(.top, 3)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(request.text).font(.akBody).foregroundStyle(Theme.textPrimary)
                        Text("Since \(request.createdAt.formatted(.dateTime.month(.abbreviated).day())) · prayed \(request.timesPrayed)×")
                            .font(.akCaption).foregroundStyle(Theme.textTertiary)
                    }
                    Spacer(minLength: 8)
                    Button { answering = request } label: {
                        Label("Answered", systemImage: "checkmark.seal")
                            .labelStyle(.iconOnly)
                            .font(.title3)
                            .foregroundStyle(Theme.sageText)
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Mark answered")
                }
                .akCard(padding: 14, cornerRadius: 18)
                .contextMenu {
                    Button { answering = request } label: { Label("Mark answered", systemImage: "checkmark.seal") }
                    Button(role: .destructive) {
                        context.delete(request)
                        try? context.save()
                    } label: { Label("Delete", systemImage: "trash") }
                }
            }
            HStack(spacing: 10) {
                TextField("Add a request, like \"her new job\"", text: $newRequest, axis: .vertical)
                    .font(.akBody)
                    .lineLimit(1...3)
                    .focused($requestFocused)
                    .submitLabel(.done)
                    .onSubmit(addRequest)
                    .accessibilityIdentifier("person.newRequest")
                Button(action: addRequest) {
                    Image(systemName: "plus")
                        .font(.body.weight(.bold))
                        .foregroundStyle(Palette.midnight)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(Palette.goldButton))
                }
                .disabled(newRequest.trimmingCharacters(in: .whitespaces).isEmpty)
                .opacity(newRequest.trimmingCharacters(in: .whitespaces).isEmpty ? 0.4 : 1)
                .accessibilityLabel("Add request")
            }
            .akCard(padding: 12, cornerRadius: 18)
        }
    }

    private func addRequest() {
        let text = newRequest.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, let person else { return }
        let request = PrayerRequest(text: text, person: person)
        context.insert(request)
        request.person = person
        try? context.save()
        newRequest = ""
        Haptics.tap()
    }

    private func answered(_ person: Person) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Answered")
            ForEach(person.answeredRequests) { request in
                AnsweredCard(request: request, personName: person.firstName) {
                    shareCard = .answered(request: request.text, person: person.firstName, note: request.answerNote, days: request.daysToAnswer)
                }
            }
        }
    }

    @ViewBuilder
    private func notes(_ person: Person) -> some View {
        let entries = journal.filter { $0.personID == person.id }
        if !entries.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "From your journal")
                ForEach(entries.prefix(5)) { entry in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(entry.createdAt.formatted(date: .abbreviated, time: .omitted)).akOverline(color: Theme.textTertiary)
                        Text(entry.text).font(.akCallout).foregroundStyle(Theme.textPrimary)
                    }
                    .akCard(padding: 14, cornerRadius: 18)
                }
            }
        }
    }
}

// MARK: - Answered

struct AnsweredCard: View {
    let request: PrayerRequest
    let personName: String
    let onShare: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.seal.fill").foregroundStyle(Theme.sageText)
                Text(personName.isEmpty ? "Answered" : "For \(personName)").akOverline(color: Theme.sageText)
                Spacer()
                if let days = request.daysToAnswer {
                    Text(days == 0 ? "same day" : "after \(days) \(days == 1 ? "day" : "days")")
                        .font(.akCaption).foregroundStyle(Theme.textTertiary)
                }
            }
            Text(request.text)
                .font(.system(.title3, design: .serif, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            if !request.answerNote.isEmpty {
                Text(request.answerNote).font(.akCallout).foregroundStyle(Theme.textSecondary)
            }
            HStack {
                if let date = request.answeredAt {
                    Text(date.formatted(date: .abbreviated, time: .omitted)).font(.akCaption).foregroundStyle(Theme.textTertiary)
                }
                Spacer()
                Button(action: onShare) {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .font(.akFootnote.weight(.semibold))
                        .foregroundStyle(Theme.goldText)
                        .frame(minHeight: 36)
                }
            }
        }
        .akCard(padding: 16, cornerRadius: 20)
    }
}

/// The wall of answered prayers: a record of God's faithfulness.
struct AnsweredWallContent: View {
    @Environment(AppModel.self) private var model
    @Query(filter: #Predicate<PrayerRequest> { $0.isAnswered }, sort: \PrayerRequest.answeredAt, order: .reverse)
    private var answered: [PrayerRequest]
    @State private var shareCard: ShareCardKind?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if answered.isEmpty {
                EmptyState(title: model.content.copy.string("emptyStates.answeredPrayers.title", default: "Answers will show up here"),
                           message: model.content.copy.string("emptyStates.answeredPrayers.message",
                                                              default: "When a prayer is answered, mark it Answered."),
                           systemImage: "checkmark.seal.fill",
                           actionTitle: model.content.copy.string("emptyStates.answeredPrayers.action", default: "Open your prayer list")) {
                    model.peopleShowsAnswered = false
                }
                .padding(.top, 20)
            } else {
                HStack(spacing: 14) {
                    ZStack {
                        Circle().fill(Palette.sage.opacity(0.2)).frame(width: 58, height: 58)
                        Image(systemName: "checkmark.seal.fill").font(.title2).foregroundStyle(Theme.sageText)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(answered.count) answered \(answered.count == 1 ? "prayer" : "prayers")")
                            .font(.akTitle3).foregroundStyle(Theme.textPrimary)
                            .accessibilityIdentifier("answered.count")
                        Text("A record of God's faithfulness to come back to.")
                            .font(.akFootnote).foregroundStyle(Theme.textSecondary)
                    }
                }
                .padding(.vertical, 4)
                ForEach(answered) { request in
                    AnsweredCard(request: request, personName: request.person?.firstName ?? "") {
                        shareCard = .answered(request: request.text, person: request.person?.firstName ?? "",
                                              note: request.answerNote, days: request.daysToAnswer)
                    }
                }
            }
        }
        .sheet(item: $shareCard) { kind in
            ShareCardSheet(kind: kind).environment(model)
        }
    }
}

struct MarkAnsweredSheet: View {
    let request: PrayerRequest
    let onSave: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var note = ""

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.seal.fill").font(.largeTitle).foregroundStyle(Theme.sageText)
                        Text(request.text).font(.akTitle3).foregroundStyle(Theme.textPrimary)
                    }
                    Text("How did God answer? (optional)").font(.akSubheadlineSemibold).foregroundStyle(Theme.textSecondary)
                    TextField("Surgery went perfectly…", text: $note, axis: .vertical)
                        .lineLimit(2...5)
                        .padding(14)
                        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.surface))
                    PrimaryButton("Mark answered", systemImage: "checkmark") {
                        onSave(note.trimmingCharacters(in: .whitespacesAndNewlines))
                        dismiss()
                    }
                    Spacer()
                }
                .padding(Spacing.page)
            }
            .navigationTitle("Answered prayer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
    }
}

// MARK: - Editor

struct PersonEditorSheet: View {
    let person: Person?
    @Environment(AppModel.self) private var model
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var relationship = ""
    @State private var emoji = ""
    @State private var firstRequest = ""
    @State private var showContacts = false

    private let relationships = ["Family", "Friend", "Church", "Small group", "Coworker", "Neighbor"]
    private let emojis = ["", "🌷", "⛪️", "👨🏻‍🦳", "👵🏼", "👶🏽", "💼", "🎓", "🏡", "❤️", "🕊️", "⭐️"]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Spacer()
                        Avatar(name: name.isEmpty ? "?" : name, emoji: emoji, colorIndex: person?.colorIndex ?? 2, size: 80)
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                    TextField("Name", text: $name)
                        .textInputAutocapitalization(.words)
                        .font(.akHeadline)
                        .accessibilityIdentifier("editor.name")
                    if person == nil {
                        Button { showContacts = true } label: {
                            Label("Choose from Contacts", systemImage: "person.crop.circle.badge.plus")
                        }
                    }
                }
                Section("Relationship") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(relationships, id: \.self) { item in
                                Button {
                                    relationship = relationship == item ? "" : item
                                    Haptics.selection()
                                } label: {
                                    Chip(text: item, isSelected: relationship == item)
                                }
                                .buttonStyle(PressScaleStyle())
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                Section("Emoji") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 10) {
                        ForEach(emojis, id: \.self) { item in
                            Button {
                                emoji = item
                                Haptics.selection()
                            } label: {
                                Text(item.isEmpty ? "Aa" : item)
                                    .font(item.isEmpty ? .akFootnote.weight(.bold) : .title2)
                                    .foregroundStyle(Theme.textPrimary)
                                    .frame(width: 44, height: 44)
                                    .background(Circle().fill(emoji == item ? Palette.gold.opacity(0.25) : Color.clear))
                                    .overlay(Circle().strokeBorder(emoji == item ? Palette.gold : Theme.stroke, lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(item.isEmpty ? "Initials" : item)
                        }
                    }
                    .padding(.vertical, 4)
                }
                if person == nil {
                    Section("First request (optional)") {
                        TextField("What can you pray for?", text: $firstRequest, axis: .vertical)
                            .lineLimit(1...3)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppBackground())
            .navigationTitle(person == nil ? "Add someone" : "Edit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .fontWeight(.semibold)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                        .accessibilityIdentifier("editor.save")
                }
            }
            .background(
                ContactPickerPresenter(isPresented: $showContacts) { picked in
                    if let picked { name = picked }
                }
            )
            .onAppear {
                if let person {
                    name = person.name
                    relationship = person.relationship
                    emoji = person.emoji
                }
            }
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if let person {
            person.name = trimmed
            person.relationship = relationship
            person.emoji = emoji
        } else {
            let created = model.addPerson(name: trimmed, relationship: relationship, emoji: emoji)
            let request = firstRequest.trimmingCharacters(in: .whitespacesAndNewlines)
            if !request.isEmpty {
                let r = PrayerRequest(text: request, person: created)
                context.insert(r)
                r.person = created
            }
        }
        try? context.save()
        Haptics.success()
        dismiss()
    }
}
