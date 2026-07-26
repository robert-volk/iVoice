import SwiftUI

struct GenerateView: View {
    @ObservedObject var flow: CreateFlow
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var library: LibraryStore
    @StateObject private var vm = GenerateViewModel()
    @StateObject private var player = AudioPlayerController()

    @State private var engine: NarrationEngine = .onDevice
    @State private var voiceID: String = ""
    @State private var rate: Double = 0.5
    @State private var pitch: Double = 1.0
    @State private var format: AudioFormat = .aac

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                enginePicker
                if engine == .onDevice {
                    voicePicker
                    RatePitchSliders(rate: $rate, pitch: $pitch).studioCard()
                } else {
                    clonedVoiceCard
                }
                formatPicker
                generateSection
            }
            .padding(.vertical, 12)
        }
        .task {
            await vm.loadVoices()
            configureDefaults()
        }
    }

    // MARK: Engine

    private var enginePicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Narration engine").font(.headline).foregroundStyle(Theme.linen)
            Picker("Engine", selection: $engine) {
                Text("On-device").tag(NarrationEngine.onDevice)
                Text("ElevenLabs").tag(NarrationEngine.elevenLabs)
            }
            .pickerStyle(.segmented)
            .disabled(!settings.hasElevenLabsKey)

            Text(engine.subtitle)
                .font(.footnote)
                .foregroundStyle(engine.isClone ? Color(hex: 0xE8A13A) : Theme.linenMuted)

            if !settings.hasElevenLabsKey {
                Text("Add an ElevenLabs API key in Settings to enable real voice cloning.")
                    .font(.caption).foregroundStyle(Theme.linenMuted)
            }
        }
        .studioCard()
    }

    private var voicePicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Voice").font(.headline).foregroundStyle(Theme.linen)
            Menu {
                ForEach(vm.onDeviceVoices) { option in
                    Button(option.name) { voiceID = option.id }
                }
            } label: {
                HStack {
                    Text(currentVoiceName).foregroundStyle(Theme.linen)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down").foregroundStyle(Theme.linenMuted)
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 10).fill(Theme.ink))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.inkLine))
            }
            Text("A system voice — not a clone of your recording.")
                .font(.caption).foregroundStyle(Theme.linenMuted)
        }
        .studioCard()
    }

    private var clonedVoiceCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Your cloned voice", systemImage: "person.wave.2.fill")
                .font(.headline).foregroundStyle(Theme.emerald)
            Text("iVoice will send your sample and this document to ElevenLabs to generate a narration in your cloned voice.")
                .font(.subheadline).foregroundStyle(Theme.linenMuted)
        }
        .studioCard()
    }

    private var formatPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Save as").font(.headline).foregroundStyle(Theme.linen)
            Picker("Format", selection: $format) {
                Text("AAC (.m4a)").tag(AudioFormat.aac)
                Text("MP3").tag(AudioFormat.mp3)
            }
            .pickerStyle(.segmented)

            if format == .mp3 && engine == .onDevice && !Mp3Encoder.isAvailable {
                Text("MP3 needs the LAME encoder (see README). On-device narration will save as AAC instead.")
                    .font(.caption).foregroundStyle(Color(hex: 0xE8A13A))
            }
        }
        .studioCard()
    }

    // MARK: Generate / result

    @ViewBuilder private var generateSection: some View {
        switch vm.phase {
        case .idle:
            Button("Generate narration") { generate() }
                .buttonStyle(PrimaryButtonStyle())

        case .generating(let p):
            VStack(spacing: 14) {
                WaveformView(levels: busyLevels, active: true).frame(height: 72)
                ProgressView(value: p).tint(Theme.emerald)
                Text("Generating… \(Int(p * 100))%")
                    .font(.footnote).foregroundStyle(Theme.linenMuted)
            }
            .studioCard()

        case .ready:
            VStack(spacing: 16) {
                if let url = vm.outputURL {
                    Text("Preview").font(.headline).foregroundStyle(Theme.linen)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    PlayerBar(player: player, url: url).studioCard()
                }
                if vm.fellBackToAAC {
                    Text("Saved as AAC — MP3 wasn't available for on-device audio.")
                        .font(.caption).foregroundStyle(Color(hex: 0xE8A13A))
                }
                Button("Save to Library") { save() }
                    .buttonStyle(PrimaryButtonStyle())
                Button("Regenerate") { vm.phase = .idle }
                    .buttonStyle(SecondaryButtonStyle())
            }

        case .failed(let message):
            VStack(spacing: 12) {
                Text(message).font(.subheadline).foregroundStyle(Theme.danger)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button("Try again") { generate() }
                    .buttonStyle(PrimaryButtonStyle())
            }
            .studioCard()
        }
    }

    // MARK: Actions

    private func configureDefaults() {
        engine = settings.hasElevenLabsKey ? settings.defaultEngine : .onDevice
        rate = settings.defaultRate
        pitch = settings.defaultPitch
        format = settings.defaultFormat
        if voiceID.isEmpty {
            voiceID = settings.selectedVoiceID ?? vm.onDeviceVoices.first?.id ?? ""
        }
    }

    private var currentVoiceName: String {
        vm.onDeviceVoices.first { $0.id == voiceID }?.name ?? "Default voice"
    }

    private func generate() {
        // Remember choices as defaults.
        settings.defaultEngine = engine
        settings.defaultFormat = format
        settings.defaultRate = rate
        settings.defaultPitch = pitch
        if engine == .onDevice { settings.selectedVoiceID = voiceID }

        let effectiveVoiceID = engine == .elevenLabs ? "cloned" : voiceID
        let text = flow.documentText.trimmingCharacters(in: .whitespacesAndNewlines)

        Task {
            await vm.generate(
                text: text,
                profile: flow.profile,
                engine: engine,
                voiceID: effectiveVoiceID,
                rate: rate,
                pitch: pitch,
                format: format,
                settings: settings,
                library: library
            )
        }
    }

    private func save() {
        let voiceName = engine == .elevenLabs ? "Cloned voice" : currentVoiceName
        _ = vm.save(documentName: flow.documentName, engine: engine, voiceName: voiceName, library: library)
        player.stop()
        flow.newDocument()
    }

    private var busyLevels: [CGFloat] {
        (0..<48).map { _ in CGFloat.random(in: 0.2...0.9) }
    }
}
