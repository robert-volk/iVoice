import Foundation
import AVFoundation

/// Narrates using the best available system voices. This is a *chosen* voice —
/// never a clone of the user's recording.
struct OnDeviceVoiceProvider: VoiceProvider {
    let engine: NarrationEngine = .onDevice
    let requiresNetwork = false

    func availableVoices() async -> [VoiceOption] {
        AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix("en") }
            .sorted { $0.name < $1.name }
            .map {
                VoiceOption(id: $0.identifier, name: displayName(for: $0), engine: .onDevice, language: $0.language)
            }
    }

    func synthesize(request: SynthesisRequest,
                    progress: @escaping (Double) -> Void) async throws -> URL {
        let renderer = SpeechRenderer()
        let voiceID = request.voiceID == "cloned" ? nil : request.voiceID
        return try await renderer.render(
            text: request.text,
            voiceIdentifier: voiceID,
            rate: request.rate,
            pitch: request.pitch,
            progress: progress
        )
    }

    private func displayName(for voice: AVSpeechSynthesisVoice) -> String {
        let quality: String
        switch voice.quality {
        case .premium:  quality = " · Premium"
        case .enhanced: quality = " · Enhanced"
        default:        quality = ""
        }
        return "\(voice.name)\(quality)"
    }

    /// Best natural female voice for speaking on-screen instructions.
    static func preferredFemaleInstructionVoice() -> AVSpeechSynthesisVoice? {
        let voices = AVSpeechSynthesisVoice.speechVoices().filter { $0.language.hasPrefix("en") }

        // Prefer premium/enhanced female voices, then any female, then a known good name.
        let female = voices.filter { $0.gender == .female }
        if let best = female.sorted(by: qualityRank).first { return best }
        if let samantha = voices.first(where: { $0.name.localizedCaseInsensitiveContains("samantha") }) {
            return samantha
        }
        return voices.sorted(by: qualityRank).first
    }

    private static func qualityRank(_ a: AVSpeechSynthesisVoice, _ b: AVSpeechSynthesisVoice) -> Bool {
        rank(a.quality) > rank(b.quality)
    }
    private static func rank(_ q: AVSpeechSynthesisVoice.Quality) -> Int {
        switch q {
        case .premium: return 3
        case .enhanced: return 2
        default: return 1
        }
    }
}
