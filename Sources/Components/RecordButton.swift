import SwiftUI

/// Large circular record control. Emerald fill with a pulsing glow while active;
/// morphs to a rounded stop-square when recording.
struct RecordButton: View {
    var isRecording: Bool
    var action: () -> Void

    @State private var pulse = false

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .stroke(Theme.inkLine, lineWidth: 4)
                    .frame(width: 88, height: 88)

                Circle()
                    .fill(Theme.emerald)
                    .frame(width: 76, height: 76)
                    .shadow(color: Theme.emeraldGlow, radius: isRecording && pulse ? 22 : 10)
                    .scaleEffect(isRecording && pulse ? 1.04 : 1.0)

                RoundedRectangle(cornerRadius: isRecording ? 6 : 38, style: .continuous)
                    .fill(Theme.ink)
                    .frame(
                        width: isRecording ? 26 : 60,
                        height: isRecording ? 26 : 60
                    )
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isRecording)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isRecording ? "Stop recording" : "Start recording")
        .onAppear { pulse = true }
        .animation(
            isRecording ? .easeInOut(duration: 0.8).repeatForever(autoreverses: true) : .default,
            value: pulse
        )
    }
}
