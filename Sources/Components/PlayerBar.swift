import SwiftUI

/// Waveform-backed playback + scrub bar driven by an AudioPlayerController.
struct PlayerBar: View {
    @ObservedObject var player: AudioPlayerController
    var url: URL

    var body: some View {
        VStack(spacing: 14) {
            // Scrub track
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.inkLine)
                    Capsule()
                        .fill(Theme.emerald)
                        .frame(width: geo.size.width * player.progress)
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            player.seek(toFraction: value.location.x / geo.size.width)
                        }
                )
            }
            .frame(height: 8)

            HStack {
                Text(timeString(player.currentTime))
                    .font(.footnote.monospaced()).foregroundStyle(Theme.linenMuted)
                Spacer()

                Button {
                    player.seek(toFraction: max(0, (player.currentTime - 15) / max(player.duration, 1)))
                } label: {
                    Image(systemName: "gobackward.15")
                }

                Button(action: player.togglePlay) {
                    Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 44))
                }
                .padding(.horizontal, 8)

                Button {
                    player.seek(toFraction: min(1, (player.currentTime + 15) / max(player.duration, 1)))
                } label: {
                    Image(systemName: "goforward.15")
                }

                Spacer()
                Text(timeString(player.duration))
                    .font(.footnote.monospaced()).foregroundStyle(Theme.linenMuted)
            }
            .foregroundStyle(Theme.emerald)
            .font(.title3)
        }
        .onAppear { player.load(url: url) }
        .onDisappear { player.stop() }
    }

    private func timeString(_ t: Double) -> String {
        guard t.isFinite, t >= 0 else { return "0:00" }
        let s = Int(t.rounded())
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}
