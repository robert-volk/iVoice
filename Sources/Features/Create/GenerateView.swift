import SwiftUI

struct GenerateView: View {
    @ObservedObject var flow: CreateFlow
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var library: LibraryStore
    @StateObject private var vm = GenerateViewModel()
    @StateObject private var player = AudioPlayerController()

    @State private var engine: NarrationEngine = .onDevice
    @State private var selectedProfileID: String = ""
    @State private var rate: Double = 0.5
    @State private var pitch: Double = 1.0
    @State private var format: AudioFormat = .aac

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                voiceSection
                enginePicker
                if engine == .onDevice {
                    RatePitchSliders(rate: $rate, pitch: $pitch).studioCard()
                } else {
                    clonedVoiceCard
                }
                formatPicker
                generateSection
            }
            .padding(.vertical, 12)
        }
        .onAppear(perform: configureDefaults)
    }

    // MARK: Voice (the user's own recordings)

    private var voiceSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Voice").font(.headline).foregroundStyle(Theme.linen)

            if library.profiles.isEmpty {
                Text("No recorded voice yet.")
                    .font(.subheadline).foregroundStyle(Theme.linenMuted)
                Button("Record your voice") { flow.go(to: .record) }
                    .buttonStyle(SecondaryButtonStyle())
            } else if library.profiles.count == 1, let only = library.profiles.first {
                HStack(spacing: 10) {
                    Image(systemName: "mic.fill").foregroundStyle(Theme.emerald)
                    Text(only.name).foregroundStyle(Theme.linen)
                    Spacer()
                    Button("Record another") { flow.go(to: .record) }
                        .font(.footnote).foregroundStyle(Theme.emerald)
                }
                .onAppear { selectedProfileID = only.id.uuidString }
            } else {
                Menu {
                    ForEach(library.profiles) { profile in
                        Button(profile.name) { selectedProfileID = profile.id.uuidString }
                    }
                } label: {
                    HStack {
                        Image(systemName: "mic.fill").foregroundStyle(Theme.emerald)
                        Text(currentProfileName).foregroundStyle(Theme.linen)
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down").foregroundStyle(Theme.linenMuted)
                    }
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Theme.ink))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.inkLine))
                }
                Button("Record another voice") { flow.go(to: .record) }
                    .font(.footnote).foregroundStyle(Theme.emerald)
            }
        }
        .studioCard()
    }

    // MARK: Engine

    private var enginePicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("How to narrate").font(.headline).foregroundStyle(Theme.linen)
            Picker("Engine", selection: $engine) {
                Text("On-device").tag(NarrationEngine.onDevice)
                Text("My cloned voice").tag(NarrationEngine.elevenLabs)
            }
            .pickerStyle(.segmented)
            .disabled(!settings.hasElevenLabsKey)

            if engine == .onDevice {
                Text("Plays a neutral system voice on-device — it isn't your recorded voice. To hear your own voice, turn on ElevenLabs cloning in Settings.")
                    .font(.caption).foregroundStyle(Theme.linenMuted)
            }

            if !settings.hasElevenLabsKey {
                Text("Add an ElevenLabs API key in Settings to narrate in your recorded voice.")
                    .font(.caption).foregroundStyle(Color(hex: 0xE8A13A))
            }
        }
        .studioCard()
    }

    private var clonedVoiceCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Your cloned voice", systemImage: "person.wave.2.fill")
                .font(.headline).foregroundStyle(Theme.emerald)
            Text("iVoice will send \(currentProfileName)'s sample and this document to ElevenLabs to narrate in your cloned voice.")
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
                .buttonStyle(PrimaryButtonStyle(enabled: !library.profiles.isEmpty))
                .disabled(library.profiles.isEmpty)

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
        if selectedProfileID.isEmpty {
            selectedProfileID = flow.profile?.id.uuidString
                ?? settings.activeProfileID
                ?? library.profiles.first?.id.uuidString
                ?? ""
        }
    }

    private var selectedProfile: VoiceProfile? {
        library.profile(id: selectedProfileID) ?? flow.profile ?? library.profiles.first
    }

    private var currentProfileName: String {
        selectedProfile?.name ?? "My Voice"
    }

    private func generate() {
        settings.defaultEngine = engine
        settings.defaultFormat = format
        settings.defaultRate = rate
        settings.defaultPitch = pitch
        settings.activeProfileID = selectedProfile?.id.uuidString

        // On-device uses a neutral system voice ("" -> default); cloud clones the profile.
        let effectiveVoiceID = engine == .elevenLabs ? "cloned" : ""
        let text = flow.documentText.trimmingCharacters(in: .whitespacesAndNewlines)

        Task {
            await vm.generate(
                text: text,
                profile: selectedProfile,
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
        let voiceName = engine == .elevenLabs
            ? "\(currentProfileName) (cloned)"
            : "System voice"
        _ = vm.save(documentName: flow.documentName, engine: engine, voiceName: voiceName, library: library)
        player.stop()
        flow.newDocument()
    }

    private var busyLevels: [CGFloat] {
        (0..<48).map { _ in CGFloat.random(in: 0.2...0.9) }
    }
}
