import SwiftUI

/// Prayer Circles (weekly leaderboards with friends) and solo Challenges.
struct TogetherView: View {
    @Environment(AppModel.self) private var model
    @State private var availability: CircleAvailability?
    @State private var circles: [PrayerCircle] = []
    @State private var standings: [String: (rank: Int, count: Int, total: Int)] = [:]
    @State private var showCreate = false
    @State private var joinCode: JoinRequest?
    @State private var pushed: TogetherRoute?
    @State private var loading = true

    struct JoinRequest: Identifiable { let id = UUID(); var code: String }

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    circlesSection
                    ChallengesSection()
                }
                .padding(.horizontal, Spacing.page)
                .padding(.bottom, 36)
            }
            .refreshable { await load() }
        }
        .navigationTitle("Together")
        .navigationBarTitleDisplayMode(.large)
        .navigationDestination(for: TogetherRoute.self) { route in destination(route) }
        .navigationDestination(item: $pushed) { route in destination(route) }
        .sheet(isPresented: $showCreate, onDismiss: { Task { await load() } }) {
            CircleFormSheet(mode: .create) { circle in
                pushed = .circle(circle.code)
            }
            .environment(model)
        }
        .sheet(item: $joinCode, onDismiss: { Task { await load() } }) { request in
            CircleFormSheet(mode: .join(request.code)) { circle in
                pushed = .circle(circle.code)
            }
            .environment(model)
        }
        .task { await load() }
        .onAppear(perform: consumePending)
        .onChange(of: model.pendingJoinCode) { _, _ in consumePending() }
        .onChange(of: model.pendingChallengeID) { _, _ in consumePending() }
        .onChange(of: model.openCircleCode) { _, _ in consumePending() }
    }

    @ViewBuilder
    private func destination(_ route: TogetherRoute) -> some View {
        switch route {
        case .circle(let code): CircleDetailView(code: code, onLeft: { Task { await load() } })
        case .challenge(let id): ChallengeDetailView(challengeID: id)
        }
    }

    private func consumePending() {
        if let code = model.pendingJoinCode {
            model.pendingJoinCode = nil
            joinCode = JoinRequest(code: code)
        }
        if let id = model.pendingChallengeID {
            model.pendingChallengeID = nil
            pushed = .challenge(id)
        }
        if let code = model.openCircleCode {
            model.openCircleCode = nil
            pushed = .circle(code)
        }
    }

    private func load() async {
        let status = await model.circles.availability()
        availability = status
        guard status == .available else {
            loading = false
            return
        }
        let joined = (try? await model.circles.myCircles()) ?? []
        circles = joined
        let week = CircleWeek.key()
        let blocked = CircleBlockList.blocked()
        var result: [String: (Int, Int, Int)] = [:]
        for circle in joined {
            let members = ((try? await model.circles.members(code: circle.code)) ?? [])
                .filter { !blocked.contains($0.id) && (!$0.isHidden || $0.isMe) }
                .sorted { $0.prayers(inWeek: week) > $1.prayers(inWeek: week) }
            let rank = (members.firstIndex { $0.isMe } ?? 0) + 1
            let myCount = members.first { $0.isMe }?.prayers(inWeek: week) ?? 0
            result[circle.code] = (rank, myCount, members.count)
        }
        standings = result.mapValues { (rank: $0.0, count: $0.1, total: $0.2) }
        loading = false
    }

    // MARK: Circles

    @ViewBuilder
    private var circlesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Prayer Circles")
            switch availability {
            case .none:
                ProgressView().frame(maxWidth: .infinity, minHeight: 120)
            case .some(.available):
                if circles.isEmpty {
                    circlesEmpty
                } else {
                    ForEach(circles) { circle in
                        NavigationLink(value: TogetherRoute.circle(circle.code)) {
                            CircleRow(circle: circle, standing: standings[circle.code])
                        }
                        .buttonStyle(PressScaleStyle())
                        .accessibilityIdentifier("circle.row.\(circle.code)")
                    }
                    HStack(spacing: 10) {
                        Button { showCreate = true } label: { Label("New circle", systemImage: "plus") }
                            .buttonStyle(QuietButtonStyle(height: 48))
                        Button { joinCode = JoinRequest(code: "") } label: { Label("Join", systemImage: "person.badge.plus") }
                            .buttonStyle(QuietButtonStyle(height: 48))
                    }
                    if let reset = CircleWeek.resetDate() {
                        Text("Weekly counts reset \(reset.formatted(.dateTime.weekday(.wide))) at midnight. Only counts and streaks are shared, never what you prayed.")
                            .font(.akCaption)
                            .foregroundStyle(Theme.textTertiary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            case .some(let status):
                iCloudExplainer(status)
            }
        }
    }

    private var circlesEmpty: some View {
        let copy = model.content.copy
        return VStack(spacing: 16) {
            HStack(spacing: -14) {
                ForEach(["🌻", "🕊️", "⛰️", "🌿"], id: \.self) { emoji in
                    Text(emoji)
                        .font(.system(size: 30))
                        .frame(width: 60, height: 60)
                        .background(Circle().fill(Theme.surfaceRaised))
                        .overlay(Circle().strokeBorder(Palette.gold.opacity(0.4), lineWidth: 1.5))
                }
            }
            Text(copy.string("emptyStates.circles.title", default: "Pray better together"))
                .font(.akTitle3).foregroundStyle(Theme.textPrimary)
            Text(copy.string("emptyStates.circles.message", default: "Start a Prayer Circle with friends, share the code, and cheer each other on."))
                .font(.akCallout).foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
            PrimaryButton(copy.string("emptyStates.circles.action", default: "Create a circle"), systemImage: "plus") { showCreate = true }
                .accessibilityIdentifier("circles.create")
            Button(copy.string("emptyStates.circles.secondaryAction", default: "Join with a code")) { joinCode = JoinRequest(code: "") }
                .font(.akSubheadlineSemibold)
                .foregroundStyle(Theme.goldText)
                .frame(minHeight: 44)
        }
        .frame(maxWidth: .infinity)
        .akCard()
    }

    private func iCloudExplainer(_ status: CircleAvailability) -> some View {
        HStack(alignment: .top, spacing: 14) {
            IconBadge(systemImage: "icloud.slash.fill", tint: Theme.goldIcon, size: 44)
            VStack(alignment: .leading, spacing: 6) {
                Text("Circles need iCloud").font(.akHeadline).foregroundStyle(Theme.textPrimary)
                Text(explainerText(status))
                    .font(.akFootnote).foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                }
                .font(.akSubheadlineSemibold)
                .foregroundStyle(Theme.goldText)
                .frame(minHeight: 44)
            }
        }
        .akCard()
    }

    private func explainerText(_ status: CircleAvailability) -> String {
        switch status {
        case .noAccount: return "Sign in to iCloud in Settings to create or join a circle. No new account, and your prayers stay on this iPhone."
        case .restricted: return "iCloud is restricted on this iPhone (Screen Time or a work profile), so circles aren't available."
        case .unavailable(let message): return message
        case .available: return ""
        }
    }
}

enum TogetherRoute: Hashable {
    case circle(String)
    case challenge(String)
}

struct CircleRow: View {
    let circle: PrayerCircle
    let standing: (rank: Int, count: Int, total: Int)?

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(Palette.gold.opacity(0.15)).frame(width: 52, height: 52)
                if let standing {
                    VStack(spacing: -2) {
                        Text("#\(standing.rank)").font(.system(.headline, design: .serif, weight: .bold)).foregroundStyle(Theme.goldText)
                    }
                } else {
                    Image(systemName: "person.3.fill").foregroundStyle(Theme.goldIcon)
                }
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(circle.name).font(.akHeadline).foregroundStyle(Theme.textPrimary)
                if let standing {
                    Text("\(standing.count) prayers this week · \(standing.total) \(standing.total == 1 ? "member" : "members")")
                        .font(.akFootnote).foregroundStyle(Theme.textSecondary)
                }
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(Theme.textTertiary)
        }
        .akCard(padding: 14, cornerRadius: 20)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Circle detail

struct CircleDetailView: View {
    let code: String
    var onLeft: () -> Void = {}
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var circle: PrayerCircle?
    @State private var members: [CircleMember] = []
    @State private var blocked: Set<String> = CircleBlockList.blocked()
    @State private var reporting: CircleMember?
    @State private var confirmLeave = false
    @State private var showInvite = false
    @State private var encouraging: CircleMember?
    @State private var hidden = false

    private var week: String { CircleWeek.key() }

    private var ranked: [CircleMember] {
        members.filter { !blocked.contains($0.id) && (!$0.isHidden || $0.isMe) }
            .sorted { a, b in
                let pa = a.prayers(inWeek: week), pb = b.prayers(inWeek: week)
                return pa == pb ? a.streak > b.streak : pa > pb
            }
    }

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    podium
                    leaderboard
                    footer
                }
                .padding(.horizontal, Spacing.page)
                .padding(.bottom, 40)
            }
            .refreshable { await load() }
        }
        .navigationTitle(circle?.name ?? "Circle")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button { showInvite = true } label: { Label("Invite friends", systemImage: "square.and.arrow.up") }
                    Button {
                        hidden.toggle()
                        let value = hidden
                        Task { try? await model.circles.setHidden(value, code: code); await load() }
                    } label: {
                        Label(hidden ? "Show me on the board" : "Hide me from the board", systemImage: hidden ? "eye" : "eye.slash")
                    }
                    Button(role: .destructive) { confirmLeave = true } label: { Label("Leave circle", systemImage: "rectangle.portrait.and.arrow.right") }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel("Circle options")
            }
        }
        .sheet(isPresented: $showInvite) {
            ShareSheet(items: [inviteText])
                .presentationDetents([.medium, .large])
        }
        .sheet(item: $encouraging) { member in
            ShareSheet(items: ["Praying for you this week, \(member.displayName) 🙏 \(AppLinks.joinWebURL(code: code).absoluteString)"])
                .presentationDetents([.medium, .large])
        }
        .sheet(item: $reporting) { member in
            ReportMemberSheet(member: member) { reason in
                Task {
                    try? await model.circles.report(memberID: member.id, code: code, reason: reason)
                    CircleBlockList.block(member.id)
                    blocked = CircleBlockList.blocked()
                    model.toast = "Thanks. We'll review it, and you won't see them here."
                }
            }
            .presentationDetents([.medium])
        }
        .confirmationDialog("Leave \(circle?.name ?? "this circle")?", isPresented: $confirmLeave, titleVisibility: .visible) {
            Button("Leave circle", role: .destructive) {
                Task {
                    try? await model.circles.leave(code: code)
                    model.toast = "You left the circle"
                    onLeft()
                    dismiss()
                }
            }
        } message: {
            Text("Your name and counts are removed from this circle.")
        }
        .task { await load() }
    }

    private var inviteText: String {
        "Join my Prayer Circle \"\(circle?.name ?? "")\" on \(AppConstants.appName). Code: \(CircleCode.pretty(code)) \(AppLinks.joinWebURL(code: code).absoluteString)"
    }

    private func load() async {
        circle = (try? await model.circles.myCircles())?.first { $0.code == code }
        members = (try? await model.circles.members(code: code)) ?? []
        hidden = members.first { $0.isMe }?.isHidden ?? false
        blocked = CircleBlockList.blocked()
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("This week").akOverline()
            Text(circle?.name ?? "")
                .font(.akLargeTitle)
                .foregroundStyle(Theme.textPrimary)
                .accessibilityIdentifier("circle.title")
            HStack(spacing: 10) {
                Button { showInvite = true } label: {
                    Label(CircleCode.pretty(code), systemImage: "square.and.arrow.up")
                        .font(.system(.subheadline, design: .monospaced, weight: .semibold))
                        .foregroundStyle(Theme.goldText)
                        .padding(.horizontal, 14)
                        .frame(minHeight: 36)
                        .background(Capsule().fill(Palette.gold.opacity(0.12)))
                }
                .accessibilityLabel("Invite code \(code). Share")
                if let reset = CircleWeek.resetDate() {
                    Text("Resets \(reset.formatted(.relative(presentation: .named)))")
                        .font(.akFootnote).foregroundStyle(Theme.textSecondary)
                }
            }
        }
        .padding(.top, 6)
    }

    @ViewBuilder
    private var podium: some View {
        let top = Array(ranked.prefix(3))
        if top.count >= 2 {
            HStack(alignment: .bottom, spacing: 12) {
                podiumColumn(top.count > 1 ? top[1] : nil, place: 2, height: 92)
                podiumColumn(top[0], place: 1, height: 124)
                podiumColumn(top.count > 2 ? top[2] : nil, place: 3, height: 72)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
        }
    }

    @ViewBuilder
    private func podiumColumn(_ member: CircleMember?, place: Int, height: CGFloat) -> some View {
        if let member {
            VStack(spacing: 8) {
                Text(member.emoji)
                    .font(.system(size: place == 1 ? 40 : 32))
                    .frame(width: place == 1 ? 72 : 60, height: place == 1 ? 72 : 60)
                    .background(Circle().fill(Theme.surfaceRaised))
                    .overlay(Circle().strokeBorder(place == 1 ? AnyShapeStyle(Palette.goldGradient) : AnyShapeStyle(Theme.strokeStrong), lineWidth: place == 1 ? 3 : 1))
                    .overlay(alignment: .top) {
                        if place == 1 {
                            Image(systemName: "crown.fill").font(.caption).foregroundStyle(Palette.gold).offset(y: -12)
                        }
                    }
                Text(member.isMe ? "You" : member.displayName)
                    .font(.akSubheadlineSemibold).foregroundStyle(Theme.textPrimary).lineLimit(1)
                ZStack(alignment: .top) {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(place == 1 ? AnyShapeStyle(Palette.goldButton) : AnyShapeStyle(Theme.surface))
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Theme.stroke, lineWidth: 1))
                    VStack(spacing: 2) {
                        Text("\(member.prayers(inWeek: week))")
                            .font(.system(.title2, design: .serif, weight: .bold))
                            .foregroundStyle(place == 1 ? Palette.midnight : Theme.textPrimary)
                        Text("prayers").font(.akCaption).foregroundStyle(place == 1 ? Palette.midnight.opacity(0.7) : Theme.textSecondary)
                    }
                    .padding(.top, 12)
                }
                .frame(height: height)
            }
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .combine)
        } else {
            Color.clear.frame(maxWidth: .infinity)
        }
    }

    private var leaderboard: some View {
        VStack(spacing: 8) {
            ForEach(Array(ranked.enumerated()), id: \.element.id) { index, member in
                leaderboardRow(member, rank: index + 1)
                    .contextMenu {
                        if !member.isMe {
                            Button { encouraging = member } label: { Label("Send encouragement", systemImage: "heart") }
                            Button { reporting = member } label: { Label("Report", systemImage: "exclamationmark.bubble") }
                            Button(role: .destructive) {
                                CircleBlockList.block(member.id)
                                blocked = CircleBlockList.blocked()
                                model.toast = "Blocked. You won't see \(member.displayName) in circles."
                            } label: { Label("Block", systemImage: "hand.raised") }
                        }
                    }
            }
        }
    }

    private func leaderboardRow(_ member: CircleMember, rank: Int) -> some View {
        HStack(spacing: 12) {
            Text("\(rank)")
                .font(.system(.headline, design: .serif, weight: .bold))
                .foregroundStyle(rank == 1 ? Theme.goldText : Theme.textSecondary)
                .frame(width: 26)
            Text(member.emoji).font(.title2)
            VStack(alignment: .leading, spacing: 2) {
                Text(member.isMe ? "\(member.displayName) (you)" : member.displayName)
                    .font(.akHeadline).foregroundStyle(Theme.textPrimary)
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill").font(.caption2).foregroundStyle(Palette.ember)
                    Text("\(member.streak)-day streak").font(.akCaption).foregroundStyle(Theme.textSecondary)
                    if member.isMe && member.isHidden {
                        Text("· hidden").font(.akCaption).foregroundStyle(Theme.textTertiary)
                    }
                }
            }
            Spacer()
            Text("\(member.prayers(inWeek: week))")
                .font(.system(.title3, design: .serif, weight: .bold))
                .foregroundStyle(Theme.textPrimary)
                .monospacedDigit()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(CardBackground(cornerRadius: 18, highlighted: member.isMe))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(rank). \(member.displayName)\(member.isMe ? ", you" : ""), \(member.prayers(inWeek: week)) prayers this week, \(member.streak) day streak")
        .accessibilityHint(member.isMe ? "" : "Touch and hold to report or block")
        .accessibilityIdentifier(member.isMe ? "circle.me" : "circle.member")
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Touch and hold someone to encourage, report or block them.")
            Text("Circles share only nicknames, emoji, weekly prayer counts and streaks. Never what you prayed.")
        }
        .font(.akCaption)
        .foregroundStyle(Theme.textTertiary)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.top, 6)
    }
}

struct ReportMemberSheet: View {
    let member: CircleMember
    let onReport: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    private let reasons = ["Offensive name", "Harassment", "Spam or fake account", "Something else"]

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
                    Text("Reports go to the \(AppConstants.appName) team with the circle code and this member's anonymous id. \(member.displayName) is blocked for you right away.")
                }
            }
            .navigationTitle("Report \(member.displayName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
    }
}

// MARK: - Create / join

struct CircleFormSheet: View {
    enum Mode: Equatable { case create, join(String) }
    let mode: Mode
    let onDone: (PrayerCircle) -> Void
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var circleName = ""
    @State private var code = ""
    @State private var nickname = ""
    @State private var emoji = "🕊️"
    @State private var working = false
    @State private var error: String?

    private let emojis = ["🕊️", "🌻", "⛰️", "🌿", "🔥", "🌙", "🌷", "⭐️", "🐑", "📖", "☀️", "🌊"]

    private var isCreate: Bool { mode == .create }

    private var circleNameProblem: NameFilter.Problem? { isCreate ? NameFilter.problem(with: circleName) : nil }
    private var nicknameProblem: NameFilter.Problem? { NameFilter.problem(with: nickname) }
    private var codeValid: Bool { isCreate || CircleCode.extract(from: code) != nil }
    private var canSubmit: Bool { !working && circleNameProblem == nil && nicknameProblem == nil && codeValid }

    var body: some View {
        NavigationStack {
            Form {
                if isCreate {
                    Section {
                        TextField("Circle name, like \"Small Group\"", text: $circleName)
                            .textInputAutocapitalization(.words)
                            .accessibilityIdentifier("circle.name")
                    } header: { Text("Circle") } footer: {
                        if !circleName.isEmpty, let problem = circleNameProblem { Text(problem.message).foregroundStyle(Theme.roseText) }
                    }
                } else {
                    Section {
                        TextField("6-letter code", text: $code)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .font(.system(.title3, design: .monospaced, weight: .semibold))
                            .accessibilityIdentifier("circle.code")
                        Button("Paste") {
                            if let pasted = UIPasteboard.general.string { code = CircleCode.extract(from: pasted) ?? pasted }
                        }
                    } header: { Text("Invite code") } footer: {
                        if !code.isEmpty && !codeValid { Text(CircleError.invalidCode.errorDescription ?? "").foregroundStyle(Theme.roseText) }
                    }
                }
                Section {
                    TextField("Nickname", text: $nickname)
                        .textInputAutocapitalization(.words)
                        .accessibilityIdentifier("circle.nickname")
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 8) {
                        ForEach(emojis, id: \.self) { item in
                            Button {
                                emoji = item
                                Haptics.selection()
                            } label: {
                                Text(item).font(.title2)
                                    .frame(width: 44, height: 44)
                                    .background(Circle().fill(emoji == item ? Palette.gold.opacity(0.25) : .clear))
                                    .overlay(Circle().strokeBorder(emoji == item ? Palette.gold : .clear, lineWidth: 1.5))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(item)
                        }
                    }
                } header: { Text("How you appear") } footer: {
                    VStack(alignment: .leading, spacing: 4) {
                        if !nickname.isEmpty, let problem = nicknameProblem { Text(problem.message).foregroundStyle(Theme.roseText) }
                        Text("Nicknames are visible to people in this circle.")
                        Text("Circles share only your nickname, emoji, weekly prayer count and streak.")
                    }
                }
                if let error {
                    Section { Text(error).foregroundStyle(Theme.roseText) }
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppBackground())
            .navigationTitle(isCreate ? "New circle" : "Join a circle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    if working {
                        ProgressView()
                    } else {
                        Button(isCreate ? "Create" : "Join", action: submit)
                            .fontWeight(.semibold)
                            .disabled(!canSubmit)
                            .accessibilityIdentifier("circle.submit")
                    }
                }
            }
            .onAppear {
                nickname = model.settings.firstName
                emoji = model.settings.circleDisplayEmoji
                if case .join(let prefill) = mode { code = prefill }
            }
        }
    }

    private func submit() {
        working = true
        error = nil
        let name = NameFilter.clean(nickname)
        model.updateSettings { $0.circleDisplayEmoji = emoji }
        Task {
            do {
                let circle: PrayerCircle
                if isCreate {
                    circle = try await model.circles.create(name: NameFilter.clean(circleName), displayName: name, emoji: emoji)
                } else {
                    guard let parsed = CircleCode.extract(from: code) else { throw CircleError.invalidCode }
                    circle = try await model.circles.join(code: parsed, displayName: name, emoji: emoji)
                }
                model.reportCircleProgress()
                Haptics.success()
                working = false
                dismiss()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { onDone(circle) }
            } catch {
                working = false
                self.error = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                Haptics.warning()
            }
        }
    }
}

// MARK: - Challenges

struct ChallengesSection: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let activeIDs = Set(model.settings.activeChallenges.map(\.id))
        let completed = Set(model.settings.completedChallengeIDs)
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Challenges")
            ForEach(model.settings.activeChallenges, id: \.id) { active in
                if let definition = model.content.challenge(id: active.id) {
                    NavigationLink(value: TogetherRoute.challenge(definition.id)) {
                        ActiveChallengeCard(definition: definition, progress: model.progress(for: definition, active: active))
                    }
                    .buttonStyle(PressScaleStyle())
                }
            }
            ForEach(model.content.challenges.filter { !activeIDs.contains($0.id) }) { definition in
                NavigationLink(value: TogetherRoute.challenge(definition.id)) {
                    HStack(spacing: 14) {
                        IconBadge(systemImage: definition.symbol, tint: completed.contains(definition.id) ? Theme.sageText : Theme.goldIcon, size: 46)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(definition.title).font(.akHeadline).foregroundStyle(Theme.textPrimary)
                            Text(definition.subtitle.isEmpty ? "\(definition.days) days" : definition.subtitle)
                                .font(.akFootnote).foregroundStyle(Theme.textSecondary).lineLimit(2)
                        }
                        Spacer(minLength: 6)
                        if completed.contains(definition.id) {
                            Image(systemName: "checkmark.seal.fill").foregroundStyle(Theme.sageText)
                                .accessibilityLabel("Completed")
                        } else {
                            Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(Theme.textTertiary)
                        }
                    }
                    .akCard(padding: 14, cornerRadius: 20)
                }
                .buttonStyle(PressScaleStyle())
            }
        }
    }
}

struct ActiveChallengeCard: View {
    let definition: ChallengeDefinition
    let progress: ChallengeProgress

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                ProgressRing(progress: progress.fraction, lineWidth: 8)
                    .frame(width: 70, height: 70)
                VStack(spacing: 0) {
                    Text("\(progress.completed)").font(.system(.title3, design: .serif, weight: .bold)).foregroundStyle(Theme.textPrimary)
                    Text("of \(progress.target)").font(.akCaption).foregroundStyle(Theme.textSecondary)
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(progress.isComplete ? "Complete" : "Day \(min(progress.dayIndex, progress.days)) of \(progress.days)").akOverline(color: progress.isComplete ? Theme.sageText : Theme.goldText)
                Text(definition.title).font(.akHeadline).foregroundStyle(Theme.textPrimary)
                if let tip = definition.tip(forDay: progress.dayIndex) {
                    Text(tip).font(.akFootnote).foregroundStyle(Theme.textSecondary).lineLimit(2)
                }
            }
            Spacer(minLength: 0)
        }
        .akCard(highlighted: true)
    }
}

struct ChallengeDetailView: View {
    let challengeID: String
    @Environment(AppModel.self) private var model
    @State private var confirmAbandon = false

    var body: some View {
        ZStack {
            AppBackground()
            if let definition = model.content.challenge(id: challengeID) {
                let active = model.settings.activeChallenges.first { $0.id == challengeID }
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        VStack(spacing: 14) {
                            ZStack {
                                if let active {
                                    ProgressRing(progress: model.progress(for: definition, active: active).fraction, lineWidth: 10)
                                        .frame(width: 150, height: 150)
                                }
                                BadgeView(milestone: definition.days, earned: model.settings.completedChallengeIDs.contains(challengeID) || active != nil, size: 108)
                            }
                            .frame(height: 170)
                            Text(definition.title).font(.akLargeTitle).foregroundStyle(Theme.textPrimary).multilineTextAlignment(.center)
                            if !definition.subtitle.isEmpty {
                                Text(definition.subtitle).font(.akHeadline).foregroundStyle(Theme.goldText).multilineTextAlignment(.center)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        Text(definition.description).font(.akBody).foregroundStyle(Theme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                        if let active {
                            let progress = model.progress(for: definition, active: active)
                            HStack(spacing: 12) {
                                StatTile(value: "\(progress.completed)/\(progress.target)", label: definition.metric == .distinctPeople ? "people" : "days prayed", systemImage: "checkmark.circle.fill")
                                StatTile(value: "\(max(0, progress.days - progress.dayIndex + 1))", label: "days left", systemImage: "calendar", tint: Theme.sageText)
                            }
                            if let tip = definition.tip(forDay: progress.dayIndex) {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Today's tip").akOverline()
                                    Text(tip).font(.akCallout).foregroundStyle(Theme.textPrimary)
                                }
                                .akCard()
                            }
                            if progress.isExpired && !progress.isComplete {
                                Text("This one slipped past. Grace is free: start again whenever you're ready.")
                                    .font(.akFootnote).foregroundStyle(Theme.roseText)
                            }
                            Button("Stop this challenge", role: .destructive) { confirmAbandon = true }
                                .font(.akSubheadlineSemibold)
                                .frame(maxWidth: .infinity, minHeight: 44)
                        } else {
                            PrimaryButton(model.settings.completedChallengeIDs.contains(challengeID) ? "Do it again" : "Start challenge", systemImage: "flag.fill") {
                                model.startChallenge(challengeID)
                            }
                            .accessibilityIdentifier("challenge.start")
                            if !definition.tips.isEmpty {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text("What to expect").akOverline()
                                    ForEach(Array(definition.tips.prefix(3).enumerated()), id: \.offset) { index, tip in
                                        HStack(alignment: .top, spacing: 10) {
                                            Text("Day \(index + 1)").font(.akCaption.weight(.bold)).foregroundStyle(Theme.goldText).frame(width: 46, alignment: .leading)
                                            Text(tip).font(.akFootnote).foregroundStyle(Theme.textSecondary)
                                        }
                                    }
                                }
                                .akCard()
                            }
                        }
                    }
                    .padding(.horizontal, Spacing.page)
                    .padding(.bottom, 40)
                }
            }
        }
        .navigationTitle("Challenge")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Stop this challenge?", isPresented: $confirmAbandon, titleVisibility: .visible) {
            Button("Stop challenge", role: .destructive) { model.abandonChallenge(challengeID) }
        }
    }
}
