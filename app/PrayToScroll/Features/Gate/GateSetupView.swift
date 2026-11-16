import SwiftUI

/// The Prayer Gate checklist: every gated app, its live status, a guide and a "Test my gate" button.
struct GateSetupView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var guideApp: GatedApp?
    @State private var showPicker = false
    var showsDoneButton = true

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    if !model.shortcutsInstalled { shortcutsMissingBanner }
                    checklist
                    appsSection
                    howItWorks
                    Button {
                        model.troubleshootApp = model.settings.gatedApps.first ?? AppCatalog.all[0]
                    } label: {
                        Label("Gate not opening? Troubleshoot", systemImage: "wrench.and.screwdriver.fill")
                            .font(.akSubheadlineSemibold)
                            .foregroundStyle(Theme.goldText)
                            .frame(minHeight: 44)
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, Spacing.page)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle("Prayer Gate")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if showsDoneButton {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.fontWeight(.semibold)
                }
            }
        }
        .sheet(item: $guideApp) { app in
            NavigationStack { GateGuideView(app: app) }
                .environment(model)
        }
        .sheet(isPresented: $showPicker) {
            NavigationStack { AppPickerView() }
                .environment(model)
        }
        .onAppear { model.reloadGateState() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            ArtImage(name: "PadlockGold") { DoorwayIllustration(symbol: "key.fill") }
                .frame(width: 130, height: 130)
                .shadow(color: Palette.gold.opacity(0.35), radius: 24)
                .frame(maxWidth: .infinity)
            Text("Your apps wait for your Amen")
                .font(.akTitle)
                .foregroundStyle(Theme.textPrimary)
                .accessibilityIdentifier("gate.title")
            Text("Apple's Shortcuts app tells \(AppConstants.appName) when a gated app opens. One automation covers all your apps. It takes about a minute, once.")
                .font(.akCallout)
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 8)
    }

    private var shortcutsMissingBanner: some View {
        HStack(spacing: 12) {
            IconBadge(systemImage: "exclamationmark.triangle.fill", tint: Theme.roseText)
            VStack(alignment: .leading, spacing: 4) {
                Text("Shortcuts isn't installed").font(.akHeadline).foregroundStyle(Theme.textPrimary)
                Text("The gate runs through Apple's free Shortcuts app.").font(.akFootnote).foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            Button("Get it") {
                if let url = URL(string: "https://apps.apple.com/app/shortcuts/id915249334") { UIApplication.shared.open(url) }
            }
            .font(.akSubheadlineSemibold)
        }
        .akCard()
    }

    private var checklist: some View {
        let apps = model.settings.gatedApps
        let protected = apps.filter { model.setupStatus(for: $0).isProtected }.count
        return VStack(alignment: .leading, spacing: 14) {
            checkRow(done: !apps.isEmpty, title: "Choose your apps", detail: apps.isEmpty ? "Start with 1–3 apps" : "\(apps.count) chosen")
            checkRow(done: protected > 0, title: "Create the automation", detail: protected == apps.count && !apps.isEmpty ? "All set" : "\(protected) of \(apps.count) protected")
            checkRow(done: model.settings.gateEnabled && protected > 0, title: "Gate is on", detail: model.settings.gateEnabled ? (model.isPaused() ? "Paused" : "On") : "Off in Settings")
        }
        .akCard()
    }

    private func checkRow(done: Bool, title: String, detail: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: done ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(done ? Theme.sageText : Theme.textTertiary)
            Text(title).font(.akBodyMedium).foregroundStyle(Theme.textPrimary)
            Spacer()
            Text(detail).font(.akFootnote).foregroundStyle(Theme.textSecondary)
        }
        .accessibilityElement(children: .combine)
    }

    private var appsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Gated apps", actionTitle: "Edit") { showPicker = true }
            if model.settings.gatedApps.isEmpty {
                Button { showPicker = true } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill").foregroundStyle(Theme.goldIcon)
                        Text("Add your first app").font(.akBodyMedium).foregroundStyle(Theme.textPrimary)
                        Spacer()
                    }
                    .akCard()
                }
                .buttonStyle(PressScaleStyle())
            }
            if !model.settings.gatedApps.isEmpty, protectedAll == false {
                PrimaryButton("Set up all apps at once", systemImage: "list.number") {
                    guideApp = model.testableGatedApp ?? model.settings.gatedApps.first
                }
                .accessibilityIdentifier("gate.setupAll")
            }
            ForEach(model.settings.gatedApps) { app in
                GateAppRow(app: app, status: model.setupStatus(for: app),
                           onGuide: { guideApp = app },
                           onTest: { model.testGate(app) })
            }
        }
    }

    private var protectedAll: Bool {
        model.settings.gatedApps.allSatisfy { model.setupStatus(for: $0).isProtected }
    }

    private var howItWorks: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("How the gate works").font(.akHeadline).foregroundStyle(Theme.textPrimary)
            bullet("lock.fill", "Open a gated app and \(AppConstants.appName) steps in with a short prayer.")
            bullet("hand.tap.fill", "Hold Amen, then tap Continue. Your app opens and stays open for your window.")
            bullet("bolt.shield.fill", "In a hurry? One emergency pass a day opens it for 5 minutes.")
            bullet("eye.slash.fill", "\(AppConstants.appName) never sees what you do inside your apps. It only knows when they open.")
        }
        .akCard()
    }

    private func bullet(_ symbol: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.goldIcon)
                .frame(width: 22)
            Text(text).font(.akSubheadline).foregroundStyle(Theme.textSecondary).fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// One gated app with its status badge, guide and test buttons.
struct GateAppRow: View {
    let app: GatedApp
    let status: GateSetupStatus
    let onGuide: () -> Void
    let onTest: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                IconBadge(systemImage: status.isProtected ? "lock.shield.fill" : "app.badge", tint: status.isProtected ? Theme.sageText : Theme.goldIcon, size: 48)
                VStack(alignment: .leading, spacing: 4) {
                    Text(app.name).font(.akHeadline).foregroundStyle(Theme.textPrimary)
                    StatusBadge(status: status)
                }
                Spacer()
            }
            HStack(spacing: 10) {
                Button(action: onGuide) {
                    Label(status.isProtected ? "Guide" : "Set up", systemImage: "list.number")
                        .font(.akSubheadlineSemibold)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .foregroundStyle(status.isProtected ? Theme.textPrimary : Palette.midnight)
                        .background(Capsule().fill(status.isProtected ? AnyShapeStyle(Theme.surfaceRaised) : AnyShapeStyle(Palette.goldButton)))
                        .overlay(Capsule().strokeBorder(Theme.stroke, lineWidth: status.isProtected ? 1 : 0))
                }
                .buttonStyle(PressScaleStyle())
                .accessibilityIdentifier("gate.guide.\(app.id)")
                Button(action: onTest) {
                    Label("Test my gate", systemImage: "checkmark.shield")
                        .font(.akSubheadlineSemibold)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .foregroundStyle(Theme.textPrimary)
                        .background(Capsule().fill(Theme.surfaceRaised))
                        .overlay(Capsule().strokeBorder(Theme.stroke, lineWidth: 1))
                }
                .buttonStyle(PressScaleStyle())
                .disabled(app.openURL == nil)
            }
        }
        .akCard()
        // The row is its own element so its id doesn't spill onto (and override) the buttons inside it.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("gate.row.\(app.id)")
    }
}

struct StatusBadge: View {
    let status: GateSetupStatus

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: symbol).font(.caption.weight(.bold))
            Text(text).font(.akCaption)
        }
        .foregroundStyle(color)
        .accessibilityElement(children: .combine)
    }

    private var symbol: String {
        switch status {
        case .notSetUp: return "circle.dashed"
        case .waitingForFirstOpen: return "hourglass"
        case .protected: return "checkmark.seal.fill"
        case .silent: return "exclamationmark.triangle.fill"
        }
    }

    private var text: String {
        switch status {
        case .notSetUp: return "Not set up"
        case .waitingForFirstOpen: return "Waiting for first open"
        case .protected(let date): return "Protected · \(GateAppRowFormat.relative(date))"
        case .silent: return "Silent for 3+ days. Run a test?"
        }
    }

    private var color: Color {
        switch status {
        case .notSetUp: return Theme.textTertiary
        case .waitingForFirstOpen: return Theme.goldText
        case .protected: return Theme.sageText
        case .silent: return Theme.roseText
        }
    }
}

enum GateAppRowFormat {
    static func relative(_ date: Date, now: Date = Date()) -> String {
        let seconds = now.timeIntervalSince(date)
        if seconds < 60 { return "just now" }
        if seconds < 3600 { return "\(Int(seconds / 60))m ago" }
        if seconds < 86_400 { return "\(Int(seconds / 3600))h ago" }
        return "\(Int(seconds / 86_400))d ago"
    }
}
