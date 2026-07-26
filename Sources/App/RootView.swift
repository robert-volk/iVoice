import SwiftUI

struct RootView: View {
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        ZStack {
            Theme.ink.ignoresSafeArea()

            if settings.hasCompletedOnboarding {
                MainTabView()
            } else {
                OnboardingView()
            }
        }
    }
}

struct MainTabView: View {
    var body: some View {
        TabView {
            CreateFlowView()
                .tabItem { Label("Create", systemImage: "waveform") }

            LibraryView()
                .tabItem { Label("Library", systemImage: "square.stack.3d.up") }

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
        .tint(Theme.emerald)
    }
}
