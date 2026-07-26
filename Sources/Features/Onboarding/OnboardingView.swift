import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 88))
                .foregroundStyle(Theme.emerald)
                .shadow(color: Theme.emeraldGlow, radius: 24)

            VStack(spacing: 12) {
                Text("iVoice")
                    .font(.largeTitle.bold())
                    .foregroundStyle(Theme.linen)
                Text("Record a voice sample, load a document, and turn it into a saved narration.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.linenMuted)
                    .padding(.horizontal, 24)
            }

            VStack(alignment: .leading, spacing: 14) {
                bullet("mic.fill", "We ask, aloud, for a short voice sample and record it.")
                bullet("checkmark.seal.fill", "You play it back and confirm before it's saved.")
                bullet("doc.text.fill", "Load a document; iVoice narrates it to an audio file.")
                bullet("lock.fill", "Private by default — nothing leaves your device unless you turn on ElevenLabs.")
            }
            .studioCard()
            .padding(.horizontal, 20)

            Spacer()

            Button("Get started") {
                settings.hasCompletedOnboarding = true
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.horizontal, 20)

            Text("On-device narration uses a system voice — it isn't a clone of your recording.")
                .font(.footnote)
                .foregroundStyle(Theme.linenMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
                .padding(.bottom, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.ink.ignoresSafeArea())
    }

    private func bullet(_ icon: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(Theme.emerald)
                .frame(width: 24)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(Theme.linen)
            Spacer(minLength: 0)
        }
    }
}
