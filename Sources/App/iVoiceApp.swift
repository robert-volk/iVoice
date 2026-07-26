import SwiftUI

@main
struct iVoiceApp: App {
    @StateObject private var settings = AppSettings()
    @StateObject private var library = LibraryStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(settings)
                .environmentObject(library)
                .tint(Theme.emerald)
                .preferredColorScheme(.dark)
        }
    }
}
