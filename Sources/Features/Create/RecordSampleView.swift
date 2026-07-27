import SwiftUI
import AVFoundation

struct RecordSampleView: View {
    @ObservedObject var flow: CreateFlow
    @StateObject private var recorder = AudioRecorder()
    @StateObject private var speaker = InstructionSpeaker()
    @State private var permissionDenied = false
    @State private var hasSpoken = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                scriptCard
                meterCard
                controls
                if let error = recorder.errorMessage {
                    Text(error).font(.footnote).foregroundStyle(Theme.danger)
                }
            }
            .padding(.vertical, 12)
        }
        .onAppear(perform: onAppear)
        .onDisappear { speaker.stop() }
        .alert("Microphone access needed", isPresented: $permissionDenied) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Enable microphone access for iVoice in the Settings app to record your sample.")
        }
    }

    private var scriptCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Read this aloud")
                    .font(.headline).foregroundStyle(Theme.linen)
                Spacer()
                // Icon-only replay of the spoken instructions (no on-screen text).
                Button {
                    speaker.speak(AppText.recordInstructions)
                } label: {
                    Image(systemName: speaker.isSpeaking ? "stop.circle" : "speaker.wave.2.circle")
                        .font(.title2)
                        .foregroundStyle(Theme.emerald)
                }
                .accessibilityLabel("Play spoken instructions")
            }
            Text(AppText.sampleScript)
                .font(.body)
                .foregroundStyle(Theme.linen)
                .lineSpacing(4)
        }
        .studioCard()
    }

    private var meterCard: some View {
        VStack(spacing: 14) {
            WaveformView(levels: recorder.levels, active: recorder.isRecording)
                .frame(height: 96)
            LevelMeterView(level: recorder.level)
            HStack {
                Text(timeString(recorder.elapsed))
                    .font(.footnote.monospaced()).foregroundStyle(Theme.linenMuted)
                Spacer()
                Text(recorder.isRecording
                     ? (recorder.meetsMinimum ? "Good — tap to stop" : "Keep going…")
                     : "Tap to record (15–90s)")
                    .font(.footnote).foregroundStyle(Theme.linenMuted)
            }
        }
        .studioCard()
    }

    private var controls: some View {
        RecordButton(isRecording: recorder.isRecording) {
            Task { await toggle() }
        }
        .padding(.top, 4)
    }

    private func onAppear() {
        // Mic permission is requested lazily when the user taps record — never
        // at launch, which could wedge the UI behind a system prompt.
        guard !hasSpoken else { return }
        hasSpoken = true
        // Pause 1 second before the spoken instructions.
        Task {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            speaker.speak(AppText.recordInstructions)
        }
    }

    private func toggle() async {
        if recorder.isRecording {
            guard let result = recorder.stop() else { return }
            flow.sampleTempURL = result.url
            flow.sampleDuration = result.duration
            flow.go(to: .confirm)
            return
        }

        // Always silence any spoken instructions first so the record session
        // can take over the audio hardware.
        speaker.stop()

        switch AVAudioApplication.shared.recordPermission {
        case .granted:
            recorder.start()
        case .denied:
            permissionDenied = true
        default: // .undetermined
            let granted = await AudioSessionManager.requestRecordPermission()
            if granted { recorder.start() } else { permissionDenied = true }
        }
    }

    private func timeString(_ t: Double) -> String {
        String(format: "%d:%02d", Int(t) / 60, Int(t) % 60)
    }
}
