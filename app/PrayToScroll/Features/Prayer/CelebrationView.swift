import SwiftUI

/// After the Amen: the streak grows, light rises, and the door opens.
struct CelebrationView: View {
    @Bindable var flow: PrayerFlow
    let onDone: () -> Void
    @Environment(AppModel.self) private var model
    @State private var shownStreak: Int = 0
    @State private var appeared = false
    @State private var journal = ""
    @State private var journalSaved = false
    @State private var shareCard: ShareCardKind?
    @FocusState private var journalFocused: Bool
    @Namespace private var flameSpace

    var body: some View {
        ZStack {
            LightParticles(count: 46, color: Palette.warmGold, speed: 1.3)
                .ignoresSafeArea()
            ScrollView {
                VStack(spacing: 22) {
                    Spacer(minLength: 30)
                    if flow.request.isSample {
                        sampleContent
                    } else {
                        streakHero
                        unlockPill
                        if let milestone = flow.completion?.newMilestones.last {
                            milestoneCard(milestone)
                        }
                        journalField
                        actions
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .onAppear {
            shownStreak = flow.completion?.previousStreak ?? 0
            withAnimation(.spring(response: 0.7, dampingFraction: 0.7).delay(0.15)) { appeared = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                    shownStreak = flow.completion?.streak.current ?? shownStreak
                }
                if (flow.completion?.streak.current ?? 0) > (flow.completion?.previousStreak ?? 0) { Haptics.success() }
            }
        }
        .sheet(item: $shareCard) { kind in
            ShareCardSheet(kind: kind)
                .environment(model)
        }
    }

    private var streakHero: some View {
        VStack(spacing: 14) {
            StreakFlame(streak: shownStreak, lit: true, size: 118)
                .matchedGeometryEffect(id: "flame", in: flameSpace)
                .scaleEffect(appeared ? 1 : 0.4)
                .opacity(appeared ? 1 : 0)
            Text("Amen.")
                .font(.system(size: 52, weight: .bold, design: .serif))
                .foregroundStyle(Palette.cream)
                .accessibilityIdentifier("celebration.title")
            Text(headline)
                .font(.akTitle3)
                .foregroundStyle(Palette.warmGold)
                .multilineTextAlignment(.center)
                .contentTransition(.numericText())
            Text(subline)
                .font(.akCallout)
                .foregroundStyle(Palette.cream.opacity(0.7))
                .multilineTextAlignment(.center)
        }
    }

    private var headline: String {
        guard let completion = flow.completion else { return "" }
        let streak = completion.streak.current
        if streak > completion.previousStreak {
            return streak == 1 ? "Day 1. Your streak starts now." : "Day \(streak). Your streak grew."
        }
        return "\(streak)-day streak, still burning."
    }

    private var subline: String {
        if !flow.personFirstName.isEmpty { return "You lifted up \(flow.personFirstName) today." }
        if flow.gatedApp != nil { return "You prayed before you scrolled." }
        return "Thanks for showing up today."
    }

    @ViewBuilder
    private var unlockPill: some View {
        if let completion = flow.completion, let until = completion.unlockedUntil {
            HStack(spacing: 10) {
                Image(systemName: "lock.open.fill")
                    .foregroundStyle(Palette.midnight)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(Palette.goldButton))
                VStack(alignment: .leading, spacing: 2) {
                    Text(unlockTitle(completion: completion, until: until))
                        .font(.akHeadline)
                        .foregroundStyle(Palette.cream)
                    Text(model.settings.gatedApps.isEmpty ? "Your gate opens the same way once it's set up." : "Your gated apps are open.")
                        .font(.akFootnote)
                        .foregroundStyle(Palette.cream.opacity(0.65))
                }
                Spacer(minLength: 0)
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Color.white.opacity(0.07)))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Palette.gold.opacity(0.35), lineWidth: 1))
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 20)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("celebration.unlock")
        }
    }

    private func unlockTitle(completion: PrayerCompletion, until: Date) -> String {
        switch completion.unlockMode {
        case .window:
            return "Unlocked for \(model.settings.unlockWindowMinutes) min"
        case .dailyKey:
            return "Daily key: open until \(until.formatted(date: .omitted, time: .shortened))"
        }
    }

    private func milestoneCard(_ milestone: Int) -> some View {
        HStack(spacing: 14) {
            BadgeView(milestone: milestone, earned: true, size: 60)
            VStack(alignment: .leading, spacing: 4) {
                Text("New milestone").akOverline(color: Palette.warmGold)
                Text(MilestoneEngine.title(for: milestone))
                    .font(.akTitle3)
                    .foregroundStyle(Palette.cream)
                Text("\(milestone) days of praying first.")
                    .font(.akFootnote)
                    .foregroundStyle(Palette.cream.opacity(0.7))
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Color.white.opacity(0.07)))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Palette.gold.opacity(0.5), lineWidth: 1))
    }

    private var journalField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("What's on your heart?")
                .font(.akSubheadlineSemibold)
                .foregroundStyle(Palette.cream.opacity(0.8))
            HStack(spacing: 10) {
                TextField("", text: $journal, prompt: Text("One line for your journal (optional)").foregroundStyle(Palette.cream.opacity(0.35)), axis: .vertical)
                    .font(.akBody)
                    .foregroundStyle(Palette.cream)
                    .lineLimit(1...4)
                    .focused($journalFocused)
                    .disabled(journalSaved)
                    .accessibilityIdentifier("celebration.journal")
                if !journal.trimmingCharacters(in: .whitespaces).isEmpty {
                    Button {
                        model.saveJournal(text: journal, personID: flow.personID, style: flow.style,
                                          verseRef: flow.style == .verse ? flow.verse.ref : "")
                        journalSaved = true
                        journalFocused = false
                        Haptics.success()
                    } label: {
                        Image(systemName: journalSaved ? "checkmark" : "arrow.up")
                            .font(.body.weight(.bold))
                            .foregroundStyle(Palette.midnight)
                            .frame(width: 36, height: 36)
                            .background(Circle().fill(Palette.goldButton))
                    }
                    .disabled(journalSaved)
                    .accessibilityLabel(journalSaved ? "Saved" : "Save to journal")
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.white.opacity(0.06)))
        }
    }

    private var actions: some View {
        VStack(spacing: 12) {
            if let app = flow.gatedApp {
                if app.openURL != nil {
                    PrimaryButton("Continue to \(app.name)", systemImage: "arrow.up.forward.app.fill") {
                        saveJournalIfNeeded()
                        model.openApp(app)
                        onDone()
                    }
                    .accessibilityIdentifier("celebration.continue")
                } else {
                    Text("Swipe back to \(app.name). It's open for you now.")
                        .font(.akCallout)
                        .foregroundStyle(Palette.cream.opacity(0.75))
                        .multilineTextAlignment(.center)
                }
                Button("Stay in \(AppConstants.appName)") {
                    saveJournalIfNeeded()
                    onDone()
                }
                .font(.akHeadline)
                .foregroundStyle(Palette.cream.opacity(0.7))
                .frame(minHeight: 44)
            } else {
                PrimaryButton("Done", systemImage: "checkmark") {
                    saveJournalIfNeeded()
                    onDone()
                }
                .accessibilityIdentifier("celebration.done")
            }
            Button {
                shareCard = .streak
            } label: {
                Label("Share my streak", systemImage: "square.and.arrow.up")
                    .font(.akSubheadlineSemibold)
                    .foregroundStyle(Palette.warmGold)
                    .frame(minHeight: 44)
            }
        }
        .padding(.top, 4)
    }

    private func saveJournalIfNeeded() {
        guard !journalSaved, !journal.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        model.saveJournal(text: journal, personID: flow.personID, style: flow.style)
        journalSaved = true
    }

    // Onboarding "Try it" ending.
    private var sampleContent: some View {
        VStack(spacing: 18) {
            MascotView(pose: .celebrating, size: 170)
                .scaleEffect(appeared ? 1 : 0.5)
            Text("That's it.")
                .font(.system(size: 46, weight: .bold, design: .serif))
                .foregroundStyle(Palette.cream)
            Text("Pray, say Amen, and your app opens. Now let's connect your real apps.")
                .font(.akBody)
                .foregroundStyle(Palette.cream.opacity(0.75))
                .multilineTextAlignment(.center)
            PrimaryButton("Continue", systemImage: "arrow.right", action: onDone)
                .padding(.top, 8)
        }
    }
}
