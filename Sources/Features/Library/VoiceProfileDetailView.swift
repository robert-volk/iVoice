import SwiftUI

struct VoiceProfileDetailView: View {
    @EnvironmentObject var library: LibraryStore
    @EnvironmentObject var settings: AppSettings
    @Environment(\.dismiss) private var dismiss
    let profile: VoiceProfile

    @StateObject private var player = AudioPlayerController()

    var body: some View {
        ZStack {
            Theme.ink.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 20) {
                    header
                    PlayerBar(player: player, url: library.sampleURL(for: profile))
                        .studioCard()
                    metadata
                    actions
                }
                .padding(20)
            }
        }
        .navigationTitle(profile.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.ink, for: .navigationBar)
    }

    private var header: some View {
        VStack(spacing: 8) {
            Image(systemName: "mic.fill")
                .font(.system(size: 54)).foregroundStyle(Theme.emerald)
                .shadow(color: Theme.emeraldGlow, radius: 16)
            Text("Reference recording — compare this against a generated narration to judge cloning accuracy.")
                .font(.subheadline).foregroundStyle(Theme.linenMuted)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 8)
    }

    private var metadata: some View {
        VStack(spacing: 10) {
            row("Length", timeString(profile.durationSeconds))
            row("Recorded", profile.createdAt.formatted(date: .abbreviated, time: .shortened))
            row("Status", settings.activeProfileID == profile.id.uuidString ? "Active" : "Not active")
        }
        .studioCard()
    }

    private var actions: some View {
        VStack(spacing: 12) {
            if settings.activeProfileID != profile.id.uuidString {
                Button {
                    settings.activeProfileID = profile.id.uuidString
                } label: {
                    Label("Use this voice", systemImage: "checkmark.circle").frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryButtonStyle())
            }

            Button(role: .destructive) {
                player.stop()
                library.deleteProfile(profile)
                dismiss()
            } label: {
                Label("Delete", systemImage: "trash").frame(maxWidth: .infinity)
            }
            .buttonStyle(SecondaryButtonStyle())
            .tint(Theme.danger)
        }
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(Theme.linenMuted)
            Spacer()
            Text(value).foregroundStyle(Theme.linen).multilineTextAlignment(.trailing)
        }
        .font(.subheadline)
    }

    private func timeString(_ t: Double) -> String {
        String(format: "%d:%02d", Int(t) / 60, Int(t) % 60)
    }
}
