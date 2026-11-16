import SwiftData
import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        ZStack {
            if model.settings.hasOnboarded {
                MainTabView()
                    .transition(.opacity)
            } else {
                OnboardingView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.5), value: model.settings.hasOnboarded)
        .fullScreenCover(item: $model.activeSession) { request in
            PrayerSessionView(request: request)
                .environment(model)
                .modelContainer(model.container)
        }
        .sheet(item: $model.verifiedGateApp) { app in
            GateVerifiedView(app: app)
                .environment(model)
        }
        .sheet(item: $model.troubleshootApp) { app in
            GateTroubleshooterView(app: app)
                .environment(model)
        }
        .overlay(alignment: .top) {
            ToastView(message: $model.toast)
        }
        .task {
            model.sceneBecameActive()
            #if DEBUG
            if model.options.isDemo, let route = model.options.route {
                try? await Task.sleep(nanoseconds: 400_000_000)
                model.openDemoRoute(route)
            }
            #endif
        }
    }
}

struct MainTabView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        TabView(selection: $model.selectedTab) {
            NavigationStack { HomeView() }
                .tabItem { Label("Today", systemImage: "sun.max.fill") }
                .tag(AppTab.today)
            WordFeedView()
                .tabItem { Label("Scroll", systemImage: "scroll.fill") }
                .tag(AppTab.word)
            NavigationStack { PeopleView() }
                .tabItem { Label("People", systemImage: "person.2.fill") }
                .tag(AppTab.people)
            NavigationStack { TogetherView() }
                .tabItem { Label("Together", systemImage: "person.3.fill") }
                .tag(AppTab.together)
            NavigationStack { StatsView() }
                .tabItem { Label("Progress", systemImage: "flame.fill") }
                .tag(AppTab.progress)
        }
        .onChange(of: model.selectedTab) { _, _ in Haptics.selection() }
        .sheet(isPresented: $model.showSettings) {
            NavigationStack { SettingsView() }
                .environment(model)
        }
        .sheet(isPresented: $model.showGateSetup) {
            NavigationStack { GateSetupView() }
                .environment(model)
        }
        .sheet(isPresented: $model.showLockSetup) {
            NavigationStack { LockSetupView() }
                .environment(model)
        }
    }
}

/// A small banner for confirmations ("Saved to your journal").
struct ToastView: View {
    @Binding var message: String?

    var body: some View {
        Group {
            if let message {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Palette.gold)
                    Text(message)
                        .font(.akSubheadlineSemibold)
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(2)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(Capsule().fill(Theme.surfaceRaised).shadow(color: Theme.shadow, radius: 16, y: 6))
                .overlay(Capsule().strokeBorder(Theme.stroke, lineWidth: 1))
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
                .task(id: message) {
                    try? await Task.sleep(nanoseconds: 2_200_000_000)
                    withAnimation(.spring()) { self.message = nil }
                }
                .accessibilityAddTraits(.updatesFrequently)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: message)
    }
}
