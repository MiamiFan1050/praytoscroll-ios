import SwiftUI

/// A circle's prayer requests: a topic and an optional short line, open for a week. Members can tap "I prayed 🙏"
/// or pray for it right away. No replies, no messages (App Review 1.2): Report and Block on every request.
struct CircleRequestsSection: View {
    let requests: [CirclePrayerRequest]
    let onAsk: () -> Void
    let onPrayed: (CirclePrayerRequest) -> Void
    let onPrayNow: (CirclePrayerRequest) -> Void
    let onReport: (CirclePrayerRequest) -> Void
    let onBlock: (CirclePrayerRequest) -> Void
    let onRemove: (CirclePrayerRequest) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Prayer requests", actionTitle: "Ask", action: onAsk)
                .accessibilityIdentifier("circle.requests")
            if requests.isEmpty {
                Button(action: onAsk) {
                    HStack(spacing: 12) {
                        ArtImage(name: "Empty-requests") {
                            IconBadge(systemImage: "hands.and.sparkles.fill", tint: Theme.goldIcon, size: 42)
                        }
                        .frame(width: 64, height: 64)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Ask your circle to pray").font(.akHeadline).foregroundStyle(Theme.textPrimary)
                            Text("Pick a topic and add a short line. It stays up for a week.")
                                .font(.akFootnote).foregroundStyle(Theme.textSecondary)
                        }
                        Spacer(minLength: 0)
                    }
                    .akCard(padding: 14, cornerRadius: 20)
                }
                .buttonStyle(PressScaleStyle())
                .accessibilityIdentifier("circle.askEmpty")
            } else {
                ForEach(requests) { request in
                    CircleRequestRow(request: request, onPrayed: { onPrayed(request) }, onPrayNow: { onPrayNow(request) })
                        .contextMenu {
                            if request.isMine {
                                Button(role: .destructive) { onRemove(request) } label: { Label("Remove request", systemImage: "trash") }
                            } else {
                                Button { onPrayNow(request) } label: { Label("Pray for this now", systemImage: "hands.and.sparkles") }
                                Button { onReport(request) } label: { Label("Report", systemImage: "exclamationmark.bubble") }
                                Button(role: .destructive) { onBlock(request) } label: { Label("Block \(request.displayName)", systemImage: "hand.raised") }
                            }
                        }
                }
            }
        }
    }
}

struct CircleRequestRow: View {
    let request: CirclePrayerRequest
    let onPrayed: () -> Void
    let onPrayNow: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Text(request.emoji).font(.title3)
                VStack(alignment: .leading, spacing: 1) {
                    Text(request.isMine ? "You asked" : request.displayName)
                        .font(.akHeadline).foregroundStyle(Theme.textPrimary)
                    Text(request.createdAt.formatted(.relative(presentation: .named)))
                        .font(.akCaption).foregroundStyle(Theme.textTertiary)
                }
                Spacer(minLength: 6)
                Chip(text: request.topic.requestTitle, systemImage: request.topic.symbol, tint: Theme.sageText)
            }
            if !request.note.isEmpty {
                Text(request.note)
                    .font(.akCallout)
                    .foregroundStyle(Theme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("circle.request.note")
            }
            HStack(spacing: 10) {
                if request.isMine {
                    Label(prayedText, systemImage: "hands.and.sparkles.fill")
                        .font(.akFootnote.weight(.semibold))
                        .foregroundStyle(Theme.goldText)
                        .accessibilityIdentifier("circle.request.count")
                } else {
                    Button(action: onPrayed) {
                        Text(request.iPrayed ? "You prayed 🙏 · \(request.prayedCount)" : "I prayed 🙏 · \(request.prayedCount)")
                            .font(.akFootnote.weight(.semibold))
                            .foregroundStyle(request.iPrayed ? Theme.sageText : Theme.goldText)
                            .padding(.horizontal, 14)
                            .frame(minHeight: 36)
                            .background(Capsule().fill((request.iPrayed ? Palette.sage : Palette.gold).opacity(0.14)))
                    }
                    .disabled(request.iPrayed)
                    .accessibilityLabel(request.iPrayed ? "You prayed. \(prayedText)" : "I prayed. \(prayedText)")
                    .accessibilityIdentifier("circle.request.prayed")
                    if !request.iPrayed {
                        Button(action: onPrayNow) {
                            Label("Pray now", systemImage: "hands.and.sparkles")
                                .font(.akFootnote.weight(.semibold))
                                .foregroundStyle(Theme.textSecondary)
                                .frame(minHeight: 36)
                        }
                        .accessibilityIdentifier("circle.request.prayNow")
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .padding(14)
        .background(CardBackground(cornerRadius: 18, highlighted: request.isMine))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(request.isMine ? "circle.request.mine" : "circle.request")
    }

    private var prayedText: String {
        switch request.prayedCount {
        case 0: return "No one has prayed yet"
        case 1: return "1 person prayed"
        default: return "\(request.prayedCount) people prayed"
        }
    }
}

/// Ask your circle: a topic and an optional line (80 characters, filtered: no links, numbers, handles or blocked words).
struct AskCircleSheet: View {
    let circleName: String
    let onPost: (PrayerTopic, String) async -> String?
    @Environment(\.dismiss) private var dismiss
    @State private var topic: PrayerTopic = .healing
    @State private var note = ""
    @State private var posting = false
    @State private var error: String?

    private var problem: RequestNoteFilter.Problem? { RequestNoteFilter.problem(with: note) }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        Text("What should \(circleName) pray about?").akOverline()
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 10)], spacing: 10) {
                            ForEach(PrayerTopic.requestTopics) { option in
                                Button { topic = option } label: {
                                    Label(option.requestTitle, systemImage: option.symbol)
                                        .font(.akCallout.weight(.semibold))
                                        .frame(maxWidth: .infinity, minHeight: 44)
                                        .foregroundStyle(topic == option ? Palette.midnight : Theme.textPrimary)
                                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .fill(topic == option ? Palette.gold : Palette.gold.opacity(0.10)))
                                }
                                .buttonStyle(PressScaleStyle())
                                .accessibilityAddTraits(topic == option ? .isSelected : [])
                                .accessibilityIdentifier("ask.topic.\(option.rawValue)")
                            }
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Add a short line (optional)").akOverline()
                            TextField("e.g. My grandma's surgery on Friday", text: $note, axis: .vertical)
                                .lineLimit(1...3)
                                .padding(14)
                                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Palette.gold.opacity(0.08)))
                                .accessibilityIdentifier("ask.note")
                            HStack {
                                if let problem {
                                    Text(problem.message).foregroundStyle(Theme.roseText).accessibilityIdentifier("ask.problem")
                                }
                                Spacer()
                                Text("\(RequestNoteFilter.clean(note).count)/\(RequestNoteFilter.maxLength)")
                                    .foregroundStyle(Theme.textTertiary).monospacedDigit()
                            }
                            .font(.akCaption)
                        }
                        if let error {
                            Text(error).font(.akFootnote).foregroundStyle(Theme.roseText)
                        }
                        PrimaryButton(posting ? "Posting…" : "Ask my circle", systemImage: "paperplane.fill") {
                            posting = true
                            Task {
                                error = await onPost(topic, RequestNoteFilter.clean(note))
                                posting = false
                                if error == nil { dismiss() }
                            }
                        }
                        .disabled(problem != nil || posting)
                        .opacity(problem != nil ? 0.5 : 1)
                        .accessibilityIdentifier("ask.post")
                        Text("Your circle sees your nickname, the topic and this line for a week. They can pray and tap “I prayed”, but there are no replies or messages. No links, phone numbers or handles.")
                            .font(.akCaption)
                            .foregroundStyle(Theme.textTertiary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(Spacing.page)
                }
            }
            .navigationTitle("Ask for prayer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
    }
}

/// Reasons for reporting a prayer request.
struct ReportRequestSheet: View {
    let request: CirclePrayerRequest
    let onReport: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    private let reasons = ["Offensive or hateful", "Harassment or bullying", "Spam or advertising", "Personal details", "Something else"]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(reasons, id: \.self) { reason in
                        Button(reason) {
                            onReport(reason)
                            dismiss()
                        }
                        .foregroundStyle(Theme.textPrimary)
                    }
                } footer: {
                    Text("Reports go to the \(AppConstants.appName) team with the circle code, the request and its author's anonymous id. \(request.displayName) is blocked for you right away.")
                }
            }
            .navigationTitle("Report request")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
    }
}
