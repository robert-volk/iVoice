import SwiftUI

struct RecordSampleView: View {
    @ObservedObject var flow: CreateFlow
    @StateObject private var recorder = AudioRecorder()
    @StateObject private var speaker = InstructionSpeaker()
    @State private var permissionDenied = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                instructionsCard
                scriptCard
                meterCard
                controls
                if let error = recorder.errorMessage {
                    Text(error).font(.footnote).foregroundStyle(Theme.danger)
                }
            }
            .padding(.vertical, 12)
        }
        .onAppear { speaker.speak(AppText.recordInstructions) }
        .onDisappear { speaker.stop() }
        .alert("Microphone access needed", isPresented: $permissionDenied) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Enable microphone access for iVoice in Settings to record your sample.")
        }
    }

    private var instructionsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Spoken instructions", systemImage: "speaker.wave.2.fill")
                    .font(.subheadline).foregroundStyle(Theme.emerald)
                Spacer()
                Button {
                    speaker.speak(AppText.recordInstructions)
                } label: {
                    Image(systemName: speaker.isSpeaking ? "stop.fill" : "play.fill")
                        .foregroundStyle(Theme.emerald)
                }
            }
            Text(AppText.recordInstructions)
                .font(.subheadline)
                .foregroundStyle(Theme.linenMuted)
        }
        .studioCard()
    }

    private var scriptCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Read this aloud")
                .font(.headline).foregroundStyle(Theme.linen)
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

    private func toggle() async {
        if recorder.isRecording {
            guard let result = recorder.stop() else { return }
            flow.sampleTempURL = result.url
            flow.sampleDuration = result.duration
            flow.go(to: .confirm)
        } else {
            let granted = await AudioSessionManager.requestRecordPermission()
            guard granted else { permissionDenied = true; return }
            speaker.stop()
            recorder.start()
        }
    }

    private func timeString(_ t: Double) -> String {
        String(format: "%d:%02d", Int(t) / 60, Int(t) % 60)
    }
}
