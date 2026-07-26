import Foundation

/// Which narration engine produced (or will produce) audio.
enum NarrationEngine: String, Codable, CaseIterable, Identifiable {
    case onDevice
    case elevenLabs

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .onDevice:   return "On-device"
        case .elevenLabs: return "ElevenLabs"
        }
    }

    var subtitle: String {
        switch self {
        case .onDevice:   return "Private · system voice · no network"
        case .elevenLabs: return "Real cloned voice · sends data to ElevenLabs"
        }
    }

    var isClone: Bool { self == .elevenLabs }
}

/// Output container for saved narrations.
enum AudioFormat: String, Codable, CaseIterable, Identifiable {
    case aac // .m4a — native
    case mp3 // requires LAME (except when source is already MP3)

    var id: String { rawValue }
    var fileExtension: String { self == .aac ? "m4a" : "mp3" }
    var displayName: String { self == .aac ? "AAC (.m4a)" : "MP3" }
}

/// A stored voice sample the user recorded and confirmed.
struct VoiceProfile: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var sampleFileName: String        // relative to the Samples directory
    var createdAt: Date = Date()
    var durationSeconds: Double
}

/// A generated narration saved to the Library.
struct Narration: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var title: String
    var sourceName: String
    var engineRaw: String
    var voiceName: String
    var formatRaw: String
    var audioFileName: String         // relative to the Narrations directory
    var durationSeconds: Double
    var fileSizeBytes: Int64
    var createdAt: Date = Date()

    var engine: NarrationEngine { NarrationEngine(rawValue: engineRaw) ?? .onDevice }
    var format: AudioFormat { AudioFormat(rawValue: formatRaw) ?? .aac }
}

/// A selectable voice offered by a `VoiceProvider`.
struct VoiceOption: Identifiable, Hashable {
    var id: String            // AVSpeechSynthesisVoice.identifier, or "cloned"
    var name: String
    var engine: NarrationEngine
    var language: String?
}

/// Everything needed to synthesize a narration.
struct SynthesisRequest {
    var text: String
    var voiceID: String
    var profile: VoiceProfile?
    var rate: Float           // 0.0...1.0 (AVSpeechUtterance scale)
    var pitch: Float          // 0.5...2.0
}
