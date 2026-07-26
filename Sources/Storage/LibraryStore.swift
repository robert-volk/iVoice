import Foundation

/// Local-first store for voice profiles and saved narrations. Metadata is JSON in
/// Application Support; audio files live under Documents/Samples and /Narrations.
@MainActor
final class LibraryStore: ObservableObject {
    @Published private(set) var profiles: [VoiceProfile] = []
    @Published private(set) var narrations: [Narration] = []

    private let profilesURL = AppPaths.appSupport.appendingPathComponent("profiles.json")
    private let narrationsURL = AppPaths.appSupport.appendingPathComponent("narrations.json")

    init() {
        load()
    }

    // MARK: Profiles

    /// Moves a recorded temp file into Samples and stores a profile.
    func addProfile(name: String, tempSampleURL: URL, duration: Double) throws -> VoiceProfile {
        let fileName = "\(UUID().uuidString).wav"
        let dest = AppPaths.sampleURL(fileName)
        try? FileManager.default.removeItem(at: dest)
        try FileManager.default.copyItem(at: tempSampleURL, to: dest)

        let profile = VoiceProfile(name: name, sampleFileName: fileName, durationSeconds: duration)
        profiles.append(profile)
        saveProfiles()
        return profile
    }

    func deleteProfile(_ profile: VoiceProfile) {
        try? FileManager.default.removeItem(at: AppPaths.sampleURL(profile.sampleFileName))
        profiles.removeAll { $0.id == profile.id }
        saveProfiles()
    }

    func profile(id: String?) -> VoiceProfile? {
        guard let id, let uuid = UUID(uuidString: id) else { return nil }
        return profiles.first { $0.id == uuid }
    }

    func sampleURL(for profile: VoiceProfile) -> URL {
        AppPaths.sampleURL(profile.sampleFileName)
    }

    // MARK: Narrations

    /// Moves a finished export into Narrations and records metadata.
    func addNarration(title: String,
                      sourceName: String,
                      engine: NarrationEngine,
                      voiceName: String,
                      format: AudioFormat,
                      tempAudioURL: URL,
                      duration: Double) throws -> Narration {
        let fileName = "\(UUID().uuidString).\(format.fileExtension)"
        let dest = AppPaths.narrationURL(fileName)
        try? FileManager.default.removeItem(at: dest)
        try FileManager.default.copyItem(at: tempAudioURL, to: dest)

        let attributes = try? FileManager.default.attributesOfItem(atPath: dest.path)
        let size = (attributes?[.size] as? NSNumber)?.int64Value ?? 0

        let narration = Narration(
            title: title,
            sourceName: sourceName,
            engineRaw: engine.rawValue,
            voiceName: voiceName,
            formatRaw: format.rawValue,
            audioFileName: fileName,
            durationSeconds: duration,
            fileSizeBytes: size
        )
        narrations.insert(narration, at: 0)
        saveNarrations()
        return narration
    }

    func deleteNarration(_ narration: Narration) {
        try? FileManager.default.removeItem(at: AppPaths.narrationURL(narration.audioFileName))
        narrations.removeAll { $0.id == narration.id }
        saveNarrations()
    }

    func rename(_ narration: Narration, to newTitle: String) {
        guard let idx = narrations.firstIndex(where: { $0.id == narration.id }) else { return }
        narrations[idx].title = newTitle
        saveNarrations()
    }

    func audioURL(for narration: Narration) -> URL {
        AppPaths.narrationURL(narration.audioFileName)
    }

    // MARK: Persistence

    private func load() {
        let decoder = JSONDecoder()
        if let data = try? Data(contentsOf: profilesURL),
           let decoded = try? decoder.decode([VoiceProfile].self, from: data) {
            profiles = decoded
        }
        if let data = try? Data(contentsOf: narrationsURL),
           let decoded = try? decoder.decode([Narration].self, from: data) {
            narrations = decoded
        }
    }

    private func saveProfiles() {
        if let data = try? JSONEncoder().encode(profiles) {
            try? data.write(to: profilesURL, options: .atomic)
        }
    }

    private func saveNarrations() {
        if let data = try? JSONEncoder().encode(narrations) {
            try? data.write(to: narrationsURL, options: .atomic)
        }
    }
}
