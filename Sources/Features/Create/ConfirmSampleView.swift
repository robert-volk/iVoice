import SwiftUI

struct ConfirmSampleView: View {
    @ObservedObject var flow: CreateFlow
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var library: LibraryStore
    @StateObject private var player = AudioPlayerController()

    @State private var profileName = "My Voice"
    @State private var saveError: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Have a listen")
                        .font(.headline).foregroundStyle(Theme.linen)
                    Text("Play your sample back. If it sounds clear and natural, keep it — otherwise re-record.")
                        .font(.subheadline).foregroundStyle(Theme.linenMuted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if let url = flow.sampleTempURL {
                    VStack(spacing: 16) {
                        WaveformView(levels: previewLevels, active: false)
                            .frame(height: 72)
                        PlayerBar(player: player, url: url)
                    }
                    .studioCard()
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Name this voice")
                        .font(.subheadline).foregroundStyle(Theme.linen)
                    TextField("My Voice", text: $profileName)
                        .textFieldStyle(.plain)
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.ink))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.inkLine))
                        .foregroundStyle(Theme.linen)
                }
                .studioCard()

                if let saveError {
                    Text(saveError).font(.footnote).foregroundStyle(Theme.danger)
                }

                VStack(spacing: 12) {
                    Button("Sounds good — use this") { confirm() }
                        .buttonStyle(PrimaryButtonStyle())
                    Button("Re-record") {
                        player.stop()
                        flow.go(to: .record)
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }
            }
            .padding(.vertical, 12)
        }
    }

    // A gentle synthetic waveform for the confirmation preview.
    private var previewLevels: [CGFloat] {
        (0..<48).map { i in 0.25 + 0.5 * CGFloat(abs(sin(Double(i) * 0.6))) }
    }

    private func confirm() {
        guard let url = flow.sampleTempURL else { return }
        do {
            let name = profileName.trimmingCharacters(in: .whitespaces).isEmpty ? "My Voice" : profileName
            let profile = try library.addProfile(name: name, tempSampleURL: url, duration: flow.sampleDuration)
            settings.activeProfileID = profile.id.uuidString
            flow.profile = profile
            player.stop()
            flow.go(to: .document)
        } catch {
            saveError = "Couldn't save the sample: \(error.localizedDescription)"
        }
    }
}
