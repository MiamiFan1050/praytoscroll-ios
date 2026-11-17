import CoreImage.CIFilterBuiltins
import SwiftUI

/// Together → Friends: my @username, "prayed for you" items, requests, and friends with their streaks next to mine.
/// No messages, ever: the only thing a friend can send is "prayed for you". Report + block on every person.
struct FriendsSection: View {
    @Environment(AppModel.self) private var model
    @State private var snapshot = FriendsSnapshot()
    @State private var availability: CircleAvailability?
    @State private var adding: AddFriendRequest?
    @State private var showShare = false
    @State private var showInvite = false
    @State private var showUsername = false
    @State private var reporting: ReportTarget?
    @State private var confirmRemove: FriendProfile?
    @State private var blocking: ReportTarget?

    struct AddFriendRequest: Identifiable { let id = UUID(); var handle: String }
    struct ReportTarget: Identifiable { var memberID: String; var handle: String; var id: String { memberID } }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Friends")
            switch availability {
            case .none:
                ProgressView().frame(maxWidth: .infinity, minHeight: 60)
            case .some(.available):
                content
            case .some:
                Text("Friends use your iCloud account. Sign in to iCloud in Settings to add friends.")
                    .font(.akFootnote)
                    .foregroundStyle(Theme.textSecondary)
                    .akCard()
            }
        }
        .task(id: model.friendsRevision) { await load() }
        .onAppear(perform: consumePending)
        .onChange(of: model.pendingFriendHandle) { _, _ in consumePending() }
        .sheet(item: $adding, onDismiss: { model.friendsRevision += 1 }) { request in
            AddFriendSheet(prefill: request.handle, snapshot: snapshot).environment(model)
        }
        .sheet(isPresented: $showShare) {
            if let handle = model.username { ShareProfileSheet(handle: handle) }
        }
        .sheet(isPresented: $showInvite) {
            if let handle = model.username { InviteContactSheet(handle: handle).environment(model) }
        }
        .sheet(isPresented: $showUsername) {
            NavigationStack { UsernameView(showsDone: true) }.environment(model)
        }
        .sheet(item: $reporting) { target in
            ReportUserSheet(handle: target.handle) { reason in
                Task {
                    try? await model.friends.report(memberID: target.memberID, handle: target.handle, reason: reason)
                    model.toast = "Reported and blocked @\(target.handle)"
                    model.friendsRevision += 1
                }
            }
        }
        .confirmationDialog(confirmRemove.map { "Remove \($0.atHandle)?" } ?? "", isPresented: Binding(
            get: { confirmRemove != nil }, set: { if !$0 { confirmRemove = nil } }), titleVisibility: .visible) {
            Button("Remove friend", role: .destructive) {
                if let friend = confirmRemove { act { try await model.friends.remove(friend: friend.memberID) } }
            }
        } message: { Text("They won't be told. You can add each other again later.") }
        .confirmationDialog(blocking.map { "Block @\($0.handle)?" } ?? "", isPresented: Binding(
            get: { blocking != nil }, set: { if !$0 { blocking = nil } }), titleVisibility: .visible) {
            Button("Block", role: .destructive) {
                if let target = blocking {
                    act { try await model.friends.block(memberID: target.memberID, handle: target.handle) }
                    model.toast = "Blocked @\(target.handle)"
                }
            }
        } message: { Text("They can't find you, send you requests or see your streak. They won't be told.") }
    }

    private func consumePending() {
        if let handle = model.pendingFriendHandle {
            model.pendingFriendHandle = nil
            adding = AddFriendRequest(handle: handle)
        }
    }

    private func load() async {
        let status = await model.friends.availability()
        availability = status
        guard status == .available else { return }
        await model.refreshUsername()
        if let loaded = try? await model.friends.snapshot() { snapshot = loaded }
    }

    private func act(_ work: @escaping () async throws -> Void) {
        Task {
            do { try await work() } catch {
                model.toast = (error as? FriendError)?.errorDescription ?? error.localizedDescription
            }
            model.friendsRevision += 1
        }
    }

    // MARK: Content

    @ViewBuilder
    private var content: some View {
        if let handle = model.username {
            meCard(handle)
            Button { showInvite = true } label: {
                Label("Invite from contacts", systemImage: "person.crop.circle.badge.plus")
            }
            .buttonStyle(QuietButtonStyle(height: 46))
            .accessibilityIdentifier("friends.invite")
        } else {
            VStack(alignment: .leading, spacing: 10) {
                Text("Pick a @username so friends can add you and see your streak. It's optional, and nobody can find you until you do.")
                    .font(.akFootnote)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button { showUsername = true } label: { Label("Pick a username", systemImage: "at") }
                    .buttonStyle(QuietButtonStyle(height: 46))
                    .accessibilityIdentifier("friends.pickUsername")
            }
            .akCard()
        }
        ForEach(snapshot.prayedForMe) { item in
            HStack(spacing: 10) {
                Text("🙏").font(.title3)
                VStack(alignment: .leading, spacing: 2) {
                    Text("@\(item.fromHandle) prayed for you").font(.akSubheadlineSemibold).foregroundStyle(Theme.textPrimary)
                    Text(item.createdAt.formatted(.relative(presentation: .named))).font(.akCaption).foregroundStyle(Theme.textTertiary)
                }
                Spacer(minLength: 0)
            }
            .akCard(padding: 14, highlighted: true)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("friends.prayedFor.\(item.fromHandle)")
        }
        ForEach(snapshot.incoming) { request in requestRow(request) }
        if model.username != nil || !snapshot.friends.isEmpty {
            friendsList
        }
        ForEach(snapshot.outgoing) { request in
            HStack {
                Text("Requested @\(request.toHandle)").font(.akFootnote).foregroundStyle(Theme.textSecondary)
                Spacer()
                Button("Cancel") { act { try await model.friends.cancelRequest(to: request.toID) } }
                    .font(.akFootnote.weight(.semibold))
                    .accessibilityIdentifier("friends.cancel.\(request.toHandle)")
            }
            .padding(.horizontal, 4)
        }
    }

    private func meCard(_ handle: String) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("@\(handle)").font(.akHeadline).foregroundStyle(Theme.textPrimary)
                    .accessibilityIdentifier("friends.myHandle")
                Text("Friends add you by this exact name.").font(.akCaption).foregroundStyle(Theme.textTertiary)
            }
            Spacer(minLength: 8)
            Button { adding = AddFriendRequest(handle: "") } label: { Label("Add", systemImage: "person.badge.plus") }
                .buttonStyle(QuietButtonStyle(height: 40))
                .fixedSize()
                .accessibilityIdentifier("friends.add")
            Button { showShare = true } label: { Image(systemName: "qrcode") }
                .buttonStyle(QuietButtonStyle(height: 40))
                .fixedSize()
                .accessibilityLabel("Share my username")
                .accessibilityIdentifier("friends.share")
        }
        .akCard(padding: 14)
    }

    private func requestRow(_ request: FriendRequest) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text("@\(request.fromHandle)").font(.akHeadline).foregroundStyle(Theme.textPrimary)
                Text("wants to be friends").font(.akCaption).foregroundStyle(Theme.textTertiary)
            }
            Spacer(minLength: 6)
            Button("Accept") { act { try await model.friends.accept(request) } }
                .buttonStyle(QuietButtonStyle(height: 38)).fixedSize()
                .accessibilityIdentifier("friends.accept.\(request.fromHandle)")
            Button("Decline") { act { try await model.friends.decline(request) } }
                .font(.akFootnote.weight(.semibold)).foregroundStyle(Theme.textSecondary)
                .accessibilityIdentifier("friends.decline.\(request.fromHandle)")
            Menu {
                Button("Report @\(request.fromHandle)", systemImage: "flag") {
                    reporting = ReportTarget(memberID: request.fromID, handle: request.fromHandle)
                }
                Button("Block @\(request.fromHandle)", systemImage: "hand.raised", role: .destructive) {
                    blocking = ReportTarget(memberID: request.fromID, handle: request.fromHandle)
                }
            } label: {
                Image(systemName: "ellipsis.circle").foregroundStyle(Theme.textSecondary).frame(width: 32, height: 44)
            }
            .accessibilityLabel("More for @\(request.fromHandle)")
            .accessibilityIdentifier("friends.requestMenu.\(request.fromHandle)")
        }
        .akCard(padding: 14)
    }

    private var friendsList: some View {
        VStack(spacing: 0) {
            // My streak first, so friends' streaks read side by side with mine.
            streakRow(emoji: model.settings.circleDisplayEmoji, name: "You", handle: model.username.map { "@" + $0 } ?? "",
                      streak: model.streak.current, prayedToday: model.streak.prayedToday, trailing: nil)
                .accessibilityElement(children: .contain)   // keeps the buttons' own ids
                .accessibilityIdentifier("friends.row.me")
            ForEach(snapshot.friends) { friend in
                Divider().overlay(Theme.stroke)
                streakRow(emoji: friend.emoji, name: friend.displayName, handle: friend.atHandle,
                          streak: friend.streak, prayedToday: friend.prayedToday(), trailing: AnyView(friendActions(friend)))
                    .accessibilityElement(children: .contain)   // keeps the buttons' own ids
                    .accessibilityIdentifier("friends.row.\(friend.handle)")
            }
            if snapshot.friends.isEmpty {
                Divider().overlay(Theme.stroke)
                HStack(spacing: 12) {
                    ArtImage(name: "Empty-friends") { EmptyView() }
                        .frame(width: 72, height: 72)
                    Text("No friends yet. Share your username, or add someone by theirs.")
                        .font(.akFootnote)
                        .foregroundStyle(Theme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.vertical, 8)
            }
        }
        .akCard(padding: 14)
    }

    private func streakRow(emoji: String, name: String, handle: String, streak: Int, prayedToday: Bool, trailing: AnyView?) -> some View {
        HStack(spacing: 10) {
            Text(emoji).font(.title2).frame(width: 36)
            VStack(alignment: .leading, spacing: 1) {
                Text(name).font(.akSubheadlineSemibold).foregroundStyle(Theme.textPrimary).lineLimit(1)
                if !handle.isEmpty { Text(handle).font(.akCaption).foregroundStyle(Theme.textTertiary).lineLimit(1) }
            }
            Spacer(minLength: 6)
            HStack(spacing: 3) {
                Image(systemName: "flame.fill").foregroundStyle(prayedToday ? Palette.gold : Theme.textTertiary)
                Text("\(streak)").font(.akNumber(18)).foregroundStyle(Theme.textPrimary).monospacedDigit()
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(streak) day streak\(prayedToday ? ", prayed today" : "")")
            if let trailing { trailing }
        }
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private func friendActions(_ friend: FriendProfile) -> some View {
        let prayed = snapshot.prayedTodayFor.contains(friend.memberID)
        Button {
            model.prayFor(friend: friend)
        } label: {
            Text(prayed ? "Prayed" : "Pray for").font(.akFootnote.weight(.semibold))
        }
        .buttonStyle(QuietButtonStyle(height: 34)).fixedSize()
        .disabled(prayed)
        .accessibilityLabel(prayed ? "You prayed for \(friend.atHandle) today" : "Pray for \(friend.atHandle)")
        .accessibilityIdentifier("friends.prayFor.\(friend.handle)")
        Menu {
            ForEach(friend.openCircles) { circle in
                Button("Join \(circle.name)", systemImage: "person.3") { join(circle) }
            }
            Button("Remove friend", systemImage: "person.badge.minus") { confirmRemove = friend }
            Button("Report \(friend.atHandle)", systemImage: "flag") {
                reporting = ReportTarget(memberID: friend.memberID, handle: friend.handle)
            }
            Button("Block \(friend.atHandle)", systemImage: "hand.raised", role: .destructive) {
                blocking = ReportTarget(memberID: friend.memberID, handle: friend.handle)
            }
        } label: {
            Image(systemName: "ellipsis").foregroundStyle(Theme.textSecondary).frame(width: 30, height: 44)
        }
        .accessibilityLabel("More for \(friend.atHandle)")
        .accessibilityIdentifier("friends.menu.\(friend.handle)")
    }

    /// Friends join each other's circles without typing a code.
    private func join(_ circle: FriendProfile.OpenCircle) {
        Task {
            do {
                _ = try await model.circles.join(code: circle.code, displayName: model.settings.circleName,
                                                 emoji: model.settings.circleDisplayEmoji)
                model.openCircleCode = circle.code
                model.circleRevision += 1
            } catch {
                model.toast = (error as? CircleError)?.errorDescription ?? error.localizedDescription
            }
        }
    }
}

// MARK: - Add a friend (exact @username only)

struct AddFriendSheet: View {
    let prefill: String
    let snapshot: FriendsSnapshot
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var result: FriendProfile?
    @State private var error: String?
    @State private var working = false
    @State private var requested: Set<String> = []   // sent from this sheet (the snapshot predates them)
    @State private var accepted: Set<String> = []
    @State private var reporting = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    UsernameField(text: $text)
                        .onSubmit(find)
                    Button(action: find) {
                        HStack { Text("Find"); Spacer(); if working { ProgressView() } }
                    }
                    .disabled(working || UsernameRules.normalize(text).count < UsernameRules.minLength)
                    .accessibilityIdentifier("friends.search.find")
                } footer: {
                    Text("Usernames are exact. There's no directory, so people can only find you if they know yours.")
                }
                if let error {
                    Section {
                        Text(error).font(.akFootnote).foregroundStyle(Theme.textSecondary)
                            .accessibilityIdentifier("friends.search.error")
                    }
                }
                if let result {
                    Section {
                        HStack(spacing: 12) {
                            Text(result.emoji).font(.largeTitle)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(result.displayName).font(.akHeadline)
                                Text(result.atHandle).font(.akFootnote).foregroundStyle(Theme.textSecondary)
                            }
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("friends.search.result")
                        statusButton(result)
                    }
                    if result.memberID != model.store.circleMemberID, model.username == nil || result.handle != model.username {
                        Section {
                            Button("Report \(result.atHandle)", role: .destructive) { reporting = true }
                            Button("Block \(result.atHandle)", role: .destructive) {
                                Task {
                                    try? await model.friends.block(memberID: result.memberID, handle: result.handle)
                                    model.toast = "Blocked \(result.atHandle)"
                                    dismiss()
                                }
                            }
                            .accessibilityIdentifier("friends.search.block")
                        }
                    }
                }
            }
            .navigationTitle("Add a friend")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }.accessibilityIdentifier("friends.search.done")
                }
            }
            .sheet(isPresented: $reporting) {
                if let result {
                    ReportUserSheet(handle: result.handle) { reason in
                        Task {
                            try? await model.friends.report(memberID: result.memberID, handle: result.handle, reason: reason)
                            model.toast = "Reported and blocked \(result.atHandle)"
                            dismiss()
                        }
                    }
                }
            }
            .task {
                guard !prefill.isEmpty, text.isEmpty else { return }
                text = prefill
                find()
            }
        }
    }

    @ViewBuilder
    private func statusButton(_ profile: FriendProfile) -> some View {
        if profile.handle == model.username {
            Text("That's you!").foregroundStyle(Theme.textSecondary)
        } else if accepted.contains(profile.memberID) || snapshot.friends.contains(where: { $0.memberID == profile.memberID }) {
            Label("Friends", systemImage: "checkmark.circle.fill").foregroundStyle(Theme.sageText)
        } else if requested.contains(profile.memberID) || snapshot.outgoing.contains(where: { $0.toID == profile.memberID }) {
            Label("Requested", systemImage: "clock").foregroundStyle(Theme.textSecondary)
                .accessibilityIdentifier("friends.search.requested")
        } else if model.username == nil {
            Text("Pick your own @username first, so they know it's you.").font(.akFootnote).foregroundStyle(Theme.textSecondary)
        } else {
            let asked = snapshot.incoming.first { $0.fromID == profile.memberID }
            Button(asked == nil ? "Send friend request" : "Accept request") { send(profile, accepting: asked) }
                .accessibilityIdentifier("friends.search.send")
        }
    }

    private func find() {
        let handle = UsernameRules.normalize(text)
        guard handle.count >= UsernameRules.minLength else { return }
        if result?.handle == handle { return }   // already showing them (e.g. the return key after Find)
        working = true
        error = nil
        result = nil
        Task {
            do {
                result = try await model.friends.lookup(handle: handle)
            } catch {
                self.error = (error as? FriendError)?.errorDescription ?? error.localizedDescription
            }
            working = false
        }
    }

    private func send(_ profile: FriendProfile, accepting request: FriendRequest?) {
        Task {
            do {
                if let request {
                    try await model.friends.accept(request)
                    accepted.insert(profile.memberID)
                } else {
                    try await model.friends.sendRequest(to: profile)
                    requested.insert(profile.memberID)
                }
                Haptics.success()
            } catch {
                self.error = (error as? FriendError)?.errorDescription ?? error.localizedDescription
            }
        }
    }
}

// MARK: - Share my username (link + QR)

struct ShareProfileSheet: View {
    let handle: String
    @Environment(\.dismiss) private var dismiss

    private var link: URL { AppLinks.profileWebURL(handle: handle) }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("@\(handle)").font(.akTitle2).foregroundStyle(Theme.textPrimary)
                if let qr = Self.qrImage(link.absoluteString) {
                    Image(uiImage: qr)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 220, height: 220)
                        .padding(14)
                        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Color.white))
                        .accessibilityLabel("QR code for \(link.absoluteString)")
                        .accessibilityIdentifier("friends.share.qr")
                }
                Text("Friends scan this, or open the link: it opens \(AppConstants.appName) if they have it, or the App Store if they don't.")
                    .font(.akFootnote)
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                ShareLink(item: link, message: Text("Add me on \(AppConstants.appName): @\(handle)")) {
                    Label("Share link", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity)
                }
                .buttonStyle(QuietButtonStyle(height: 50))
                .accessibilityIdentifier("friends.share.link")
                Button {
                    UIPasteboard.general.url = link
                } label: {
                    Label(link.absoluteString.replacingOccurrences(of: "https://", with: ""), systemImage: "doc.on.doc")
                        .font(.akFootnote)
                        .lineLimit(1)
                }
                Spacer()
            }
            .padding(24)
            .navigationTitle("My username")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
        }
        .presentationDetents([.large])
    }

    static func qrImage(_ text: String) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(text.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: 10, y: 10)),
              let cg = CIContext().createCGImage(output, from: output.extent) else { return nil }
        return UIImage(cgImage: cg)
    }
}

// MARK: - Report a username

struct ReportUserSheet: View {
    let handle: String
    let onReport: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    private let reasons = ["Offensive username", "Harassment", "Pretending to be someone", "Spam or fake account", "Something else"]

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
                    Text("Reports go to the \(AppConstants.appName) team with @\(handle) and an anonymous id. They're blocked for you right away.")
                }
            }
            .navigationTitle("Report @\(handle)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
    }
}
