#if STRICT_LOCK   // the Screen Time lock: only in the project-strictlock.yml build (v1.2)
import SwiftUI

enum LockAuthorization: Equatable, Sendable {
    case notDetermined, approved, denied
}

/// The Screen Time lock behind one small API, so AppModel's lock lifecycle runs (and is unit-tested) the same with
/// Apple's shields, the Debug demo and a test fake. AppModel decides what to do (ShieldPlanner); this only does it.
@MainActor
protocol AppLock: AnyObject {
    var authorization: LockAuthorization { get }
    func requestAuthorization() async -> LockAuthorization
    /// Apps + categories + sites picked.
    var lockedCount: Int { get }
    var scheduledRelock: Date? { get }
    var isMonitoring: Bool { get }
    func shield()
    func unshield()
    func scheduleRelock(at end: Date, now: Date) throws
    func cancelRelock()
    /// Erase everything: forget the picked apps.
    func forgetSelection()
    /// The picked apps' real icons (Apple renders them; the app never learns the names).
    func icons(size: CGFloat, limit: Int) -> AnyView
    /// Attach to any view: presents the app picker while `isPresented` is true and calls `onChange` after edits.
    func picker(isPresented: Binding<Bool>, onChange: @escaping () -> Void) -> AnyView
}

extension AppLock {
    var hasSelection: Bool { lockedCount > 0 }
}

#if !NO_SCREEN_TIME
import FamilyControls

/// The real lock: FamilyControls (.individual) + ManagedSettings shields + a DeviceActivity relock timer.
final class ScreenTimeLock: AppLock {
    var authorization: LockAuthorization {
        switch AuthorizationCenter.shared.authorizationStatus {
        case .approved: return .approved
        case .denied: return .denied
        default: return .notDetermined
        }
    }

    func requestAuthorization() async -> LockAuthorization {
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
        } catch {
            return .denied
        }
        return authorization
    }

    var lockedCount: Int { StrictLockStore.lockedCount }
    var scheduledRelock: Date? { SharedStore.shared.relockScheduledFor }
    var isMonitoring: Bool { StrictLockStore.isMonitoring }
    func shield() { StrictLockStore.shield() }
    func unshield() { StrictLockStore.unshield() }
    func scheduleRelock(at end: Date, now: Date) throws { try StrictLockStore.scheduleRelock(at: end, now: now) }
    func cancelRelock() { StrictLockStore.cancelRelock() }
    func forgetSelection() { StrictLockStore.selection = FamilyActivitySelection() }

    func icons(size: CGFloat, limit: Int) -> AnyView {
        AnyView(ScreenTimeIcons(size: size, limit: limit))
    }

    func picker(isPresented: Binding<Bool>, onChange: @escaping () -> Void) -> AnyView {
        AnyView(ScreenTimePickerHost(isPresented: isPresented, onChange: onChange))
    }
}

private struct ScreenTimeIcons: View {
    let size: CGFloat
    let limit: Int

    var body: some View {
        let selection = StrictLockStore.selection
        let apps = Array(selection.applicationTokens).prefix(limit)
        let extra = selection.applicationTokens.count - apps.count + selection.categoryTokens.count + selection.webDomainTokens.count
        HStack(spacing: 8) {
            ForEach(Array(apps), id: \.self) { token in
                Label(token)
                    .labelStyle(.iconOnly)
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: size * 0.23, style: .continuous))
            }
            if extra > 0 {
                Text("+\(extra)")
                    .font(.akFootnote.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(minWidth: size, minHeight: size)
                    .background(RoundedRectangle(cornerRadius: size * 0.23, style: .continuous).fill(Theme.surfaceRaised))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(selection.applicationTokens.count) apps and \(selection.categoryTokens.count) categories locked")
        .accessibilityIdentifier("lock.icons")
    }
}

private struct ScreenTimePickerHost: View {
    @Binding var isPresented: Bool
    let onChange: () -> Void
    @State private var selection = StrictLockStore.selection

    var body: some View {
        Color.clear
            .familyActivityPicker(headerText: "Choose the apps that wait for your Amen",
                                  footerText: "Start with the 1–3 you open without thinking. You can change this any time.",
                                  isPresented: $isPresented, selection: $selection)
            .onChange(of: selection) { _, newValue in
                StrictLockStore.selection = newValue
                onChange()
            }
            .onChange(of: isPresented) { _, shown in
                if shown { selection = StrictLockStore.selection }
            }
    }
}
#else
/// The Mac Catalyst unit-test runner has no Screen Time: everything reads as "not allowed".
final class ScreenTimeLock: AppLock {
    var authorization: LockAuthorization { .denied }
    func requestAuthorization() async -> LockAuthorization { .denied }
    var lockedCount: Int { 0 }
    var scheduledRelock: Date? { nil }
    var isMonitoring: Bool { false }
    func shield() {}
    func unshield() {}
    func scheduleRelock(at end: Date, now: Date) throws {}
    func cancelRelock() {}
    func forgetSelection() {}
    func icons(size: CGFloat, limit: Int) -> AnyView { AnyView(EmptyView()) }
    func picker(isPresented: Binding<Bool>, onChange: @escaping () -> Void) -> AnyView { AnyView(EmptyView()) }
}
#endif

#if DEBUG
/// Debug builds only (demo, UI tests, screenshots): the simulator can't show Apple's picker or real shields, so this
/// stands in with the catalog's app icons and remembers what is "shielded". Not in the Release binary.
final class DemoLock: AppLock {
    private(set) var authorization: LockAuthorization
    private(set) var pickedIDs: [String]
    private(set) var isShielded = false
    private(set) var scheduledRelock: Date?
    var isMonitoring: Bool { scheduledRelock.map { $0 > Date() } ?? false }

    init(authorized: Bool = true, picked: [String] = ["instagram", "tiktok", "youtube"]) {
        authorization = authorized ? .approved : .notDetermined
        pickedIDs = picked
    }

    func requestAuthorization() async -> LockAuthorization {
        authorization = .approved
        return authorization
    }

    var lockedCount: Int { pickedIDs.count }
    func shield() { isShielded = true }
    func unshield() { isShielded = false }
    func scheduleRelock(at end: Date, now: Date) throws { scheduledRelock = end }
    func cancelRelock() { scheduledRelock = nil }
    func forgetSelection() { pickedIDs = [] }

    func setPicked(_ ids: [String]) { pickedIDs = ids }

    func icons(size: CGFloat, limit: Int) -> AnyView {
        // Names only: the demo never draws a fake app logo (the real lock shows Apple's icons).
        let apps = pickedIDs.compactMap { AppCatalog.app(id: $0, customApps: []) }
        let shown = min(limit, 3)
        return AnyView(
            HStack(spacing: 6) {
                ForEach(apps.prefix(shown)) { AppNameChip(app: $0) }
                if apps.count > shown {
                    Text("+\(apps.count - shown)").font(.akFootnote.weight(.semibold)).foregroundStyle(Theme.textSecondary)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(apps.count) apps locked: " + apps.map(\.name).joined(separator: ", "))
            .accessibilityIdentifier("lock.icons")
        )
    }

    func picker(isPresented: Binding<Bool>, onChange: @escaping () -> Void) -> AnyView {
        AnyView(Color.clear.sheet(isPresented: isPresented) {
            DemoLockPicker(lock: self, onChange: onChange)
        })
    }
}

/// Stand-in for Apple's FamilyActivityPicker in the Debug demo.
private struct DemoLockPicker: View {
    let lock: DemoLock
    let onChange: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var picked: Set<String> = []

    var body: some View {
        NavigationStack {
            List(AppCatalog.all) { app in
                Button {
                    if picked.contains(app.id) { picked.remove(app.id) } else { picked.insert(app.id) }
                } label: {
                    HStack {
                        Text(app.name).foregroundStyle(Theme.textPrimary)
                        Spacer()
                        Image(systemName: picked.contains(app.id) ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(picked.contains(app.id) ? Palette.gold : Theme.textTertiary)
                    }
                }
                .accessibilityIdentifier("lockpicker.row.\(app.id)")
                .accessibilityAddTraits(picked.contains(app.id) ? .isSelected : [])
            }
            .navigationTitle("Choose apps")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        lock.setPicked(AppCatalog.all.map(\.id).filter(picked.contains))
                        onChange()
                        dismiss()
                    }
                    .accessibilityIdentifier("lockpicker.done")
                }
            }
        }
        .onAppear { picked = Set(lock.pickedIDs) }
    }
}
#endif
#endif
