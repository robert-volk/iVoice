import Foundation

/// Abstraction over "turn text into a narration audio file". Two concrete
/// implementations ship: on-device (system voice) and ElevenLabs (real cloning).
protocol VoiceProvider {
    var engine: NarrationEngine { get }
    var requiresNetwork: Bool { get }

    func availableVoices() async -> [VoiceOption]

    /// Synthesize and return a URL to an audio file to be exported.
    /// On-device returns a .caf (PCM); ElevenLabs returns a .mp3.
    func synthesize(request: SynthesisRequest,
                    progress: @escaping (Double) -> Void) async throws -> URL
}
