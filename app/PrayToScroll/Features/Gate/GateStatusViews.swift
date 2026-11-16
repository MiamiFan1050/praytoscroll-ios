import SwiftUI

/// "✓ Instagram is protected": shown when "Test my gate" reaches the app through the automation.
struct GateVerifiedView: View {
    let app: GatedApp
    @Environment(\.dismiss) private var dismiss
    @State private var appeared = false

    var body: some View {
        ZStack {
            AppBackground()
            LightParticles(count: 36, color: Palette.warmGold, speed: 1.4).ignoresSafeArea()
            VStack(spacing: 20) {
                Spacer()
                ZStack {
                    Circle().fill(Palette.sage.opacity(0.2)).frame(width: 170, height: 170)
                        .scaleEffect(appeared ? 1 : 0.6)
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 64, weight: .semibold))
                        .foregroundStyle(Palette.warmGold)
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundStyle(Palette.sage, Palette.midnight)
                        .background(Circle().fill(Palette.midnight).padding(4))
                        .offset(x: 46, y: 46)
                        .scaleEffect(appeared ? 1 : 0.2)
                }
                Text("\(app.name) is protected")
                    .font(.akLargeTitle)
                    .foregroundStyle(Theme.textPrimary)
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier("verified.title")
                Text("Your automation works. Next time you open \(app.name) without praying, \(AppConstants.appName) will step in first.")
                    .font(.akCallout)
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
                PrimaryButton("Wonderful", systemImage: "checkmark") { dismiss() }
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 24)
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) { appeared = true }
        }
    }
}

/// Seven checks, in the order that fixes most broken gates.
struct GateTroubleshooterView: View {
    let app: GatedApp
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var checked: Set<Int> = []

    private var items: [(String, String, String)] {
        [
            ("bolt.fill", "Run Immediately is on", "In the automation, choose Run Immediately (not Run After Confirmation)."),
            ("bell.slash.fill", "Notify When Run is off", "Optional, but it removes the banner every time \(app.name) opens."),
            ("app.badge.checkmark.fill", "\(app.name) is ticked", "Open the automation and check \(app.name) is one of the apps under When."),
            ("togglepower", "The automation is switched on", "Automations you import arrive switched off. Tap it and turn it on."),
            ("arrow.clockwise", "Not just restarted", "After a restart, automations can take about 2 minutes to wake up."),
            ("moon.fill", "No Focus mode blocking it", "Some Focus filters stop automations. Try again with Focus off."),
            ("square.stack.3d.up.fill", "Shortcuts is installed", model.shortcutsInstalled ? "It is. Nice." : "Install Shortcuts from the App Store, then set up the automation again."),
        ]
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        HStack(spacing: 14) {
                            IconBadge(systemImage: "wrench.and.screwdriver.fill", tint: Theme.goldIcon, size: 52)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Let's get \(app.name) protected")
                                    .font(.akTitle2)
                                    .foregroundStyle(Theme.textPrimary)
                                Text("The test didn't reach \(AppConstants.appName). Check these, then test again.")
                                    .font(.akFootnote)
                                    .foregroundStyle(Theme.textSecondary)
                            }
                        }
                        VStack(spacing: 10) {
                            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                                Button {
                                    if checked.contains(index) { checked.remove(index) } else { checked.insert(index) }
                                    Haptics.selection()
                                } label: {
                                    HStack(alignment: .top, spacing: 14) {
                                        Image(systemName: checked.contains(index) ? "checkmark.circle.fill" : "\(index + 1).circle")
                                            .font(.title2)
                                            .foregroundStyle(checked.contains(index) ? Theme.sageText : Theme.goldIcon)
                                        VStack(alignment: .leading, spacing: 4) {
                                            Label(item.1, systemImage: item.0)
                                                .labelStyle(.titleOnly)
                                                .font(.akHeadline)
                                                .foregroundStyle(Theme.textPrimary)
                                            Text(item.2)
                                                .font(.akFootnote)
                                                .foregroundStyle(Theme.textSecondary)
                                                .fixedSize(horizontal: false, vertical: true)
                                        }
                                        Spacer(minLength: 0)
                                    }
                                    .akCard(padding: 14, cornerRadius: 18)
                                }
                                .buttonStyle(PressScaleStyle())
                                .accessibilityAddTraits(checked.contains(index) ? .isSelected : [])
                            }
                        }
                        PrimaryButton("Test again", systemImage: "checkmark.shield.fill") {
                            dismiss()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { model.testGate(app) }
                        }
                        .disabled(app.openURL == nil)
                        Button("Open Shortcuts") {
                            if let url = URL(string: "shortcuts://") { UIApplication.shared.open(url) }
                        }
                        .font(.akSubheadlineSemibold)
                        .foregroundStyle(Theme.goldText)
                        .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .padding(Spacing.page)
                }
            }
            .navigationTitle("Troubleshoot")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
            }
        }
    }
}

/// Choose which apps the gate stands in front of. Names only: the real app (with its real icon) is picked in Apple's
/// Shortcuts app; this list is how we send you back to it after you pray.
struct AppPickerView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    var embedded = false
    @State private var showAdd = false

    var body: some View {
        ZStack {
            if !embedded { AppBackground() }
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if !embedded {
                        Text("Start with the 1–3 apps you open without thinking. You can add more later.")
                            .font(.akCallout)
                            .foregroundStyle(Theme.textSecondary)
                    }
                    AppGrid()
                    Button { showAdd = true } label: {
                        Label("Add another app", systemImage: "plus.circle.fill")
                            .font(.akSubheadlineSemibold)
                            .foregroundStyle(Theme.goldText)
                            .frame(minHeight: 44)
                    }
                    .accessibilityIdentifier("apps.addAnother")
                }
                .padding(embedded ? 0 : Spacing.page)
            }
            .scrollDisabled(embedded)
        }
        .navigationTitle("Gated apps")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !embedded {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() }.fontWeight(.semibold) }
            }
        }
        .sheet(isPresented: $showAdd) {
            AddAppSheet()
                .environment(model)
                .presentationDetents([.large])
        }
    }
}

/// The selectable list of apps: the featured ones plus any you added. Names only.
struct AppGrid: View {
    @Environment(AppModel.self) private var model
    private let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

    var body: some View {
        let selected = Set(model.settings.gatedAppIDs)
        let added = model.settings.customApps.filter { app in !AppCatalog.featured.contains { $0.id == app.id } }
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(AppCatalog.featured + added) { app in
                let isOn = selected.contains(app.id)
                Button {
                    Haptics.selection()
                    model.updateSettings { s in
                        if isOn { s.gatedAppIDs.removeAll { $0 == app.id } } else { s.gatedAppIDs.append(app.id) }
                    }
                } label: {
                    HStack(spacing: 8) {
                        Text(app.name)
                            .font(.akSubheadlineSemibold)
                            .foregroundStyle(Theme.textPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        Spacer(minLength: 4)
                        Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 20))
                            .foregroundStyle(isOn ? AnyShapeStyle(Palette.gold) : AnyShapeStyle(Theme.textTertiary))
                    }
                    .padding(.horizontal, 14)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(isOn ? Palette.gold.opacity(0.14) : Theme.surface))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(isOn ? Palette.gold : Theme.stroke, lineWidth: isOn ? 2 : 1))
                }
                .buttonStyle(PressScaleStyle())
                .accessibilityLabel(app.name)
                .accessibilityAddTraits(isOn ? .isSelected : [])
                .accessibilityIdentifier("app.\(app.id)")
            }
        }
    }
}

/// "Add another app": search popular apps by name, or add any app by name. Never asks for a URL scheme.
struct AddAppSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var otherName = ""
    @State private var addingOther = false

    private var results: [GatedApp] {
        AppCatalog.search(query, excluding: Set(model.settings.customApps.map(\.id)))
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(results) { app in
                        Button { add(app) } label: {
                            HStack {
                                Text(app.name).foregroundStyle(Theme.textPrimary)
                                Spacer()
                                Image(systemName: "plus.circle.fill").foregroundStyle(Theme.goldIcon)
                            }
                            .frame(minHeight: 36)
                        }
                        .accessibilityIdentifier("addApp.\(app.id)")
                    }
                    Button {
                        otherName = query.trimmingCharacters(in: .whitespaces)
                        addingOther = true
                    } label: {
                        Label(query.isEmpty ? "Other app…" : "Other app: “\(query.trimmingCharacters(in: .whitespaces))”", systemImage: "square.and.pencil")
                            .foregroundStyle(Theme.goldText)
                            .frame(minHeight: 36)
                    }
                    .accessibilityIdentifier("addApp.other")
                } footer: {
                    Text("You’ll pick the real app in Shortcuts. This list is just so we can send you back to it.")
                }
            }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search apps")
            .scrollContentBackground(.hidden)
            .background(AppBackground())
            .navigationTitle("Add an app")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
            .alert("Other app", isPresented: $addingOther) {
                TextField("App name", text: $otherName)
                    .textInputAutocapitalization(.words)
                Button("Add") {
                    let name = otherName.trimmingCharacters(in: .whitespacesAndNewlines)
                    if name.count >= 2 { add(GatedApp.named(name)) }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("After you pray, we’ll remind you to open it yourself.")
            }
        }
    }

    private func add(_ app: GatedApp) {
        Haptics.selection()
        model.updateSettings { s in
            s.customApps.removeAll { $0.id == app.id }
            s.customApps.append(app)
            if !s.gatedAppIDs.contains(app.id) { s.gatedAppIDs.append(app.id) }
        }
        model.toast = "\(app.name) added"
        dismiss()
    }
}
