import Foundation
import AVFoundation

enum SpeechRenderError: LocalizedError {
    case noAudioProduced
    var errorDescription: String? { "The system voice produced no audio for this text." }
}

/// Renders text to a linear-PCM .caf file using AVSpeechSynthesizer's write API.
final class SpeechRenderer {
    private let synthesizer = AVSpeechSynthesizer()

    /// - Returns: URL of a .caf file containing the rendered speech.
    func render(text: String,
                voiceIdentifier: String?,
                rate: Float,
                pitch: Float,
                progress: @escaping (Double) -> Void) async throws -> URL {

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("tts-\(UUID().uuidString).caf")

        let utterance = AVSpeechUtterance(string: text)
        if let id = voiceIdentifier, let voice = AVSpeechSynthesisVoice(identifier: id) {
            utterance.voice = voice
        }
        utterance.rate = rate
        utterance.pitchMultiplier = pitch

        // Rough progress: estimate total frames from a nominal 22.05kHz-ish output.
        let estimatedFrames = Double(max(text.count, 1)) * 900.0
        var writtenFrames: Double = 0
        let once = ResumeOnce()

        return try await withCheckedThrowingContinuation { (cont: CheckedContinuation<URL, Error>) in
            var audioFile: AVAudioFile?

            synthesizer.write(utterance) { (buffer: AVAudioBuffer) in
                guard let pcm = buffer as? AVAudioPCMBuffer else { return }

                if pcm.frameLength == 0 {
                    once.run {
                        if audioFile == nil {
                            cont.resume(throwing: SpeechRenderError.noAudioProduced)
                        } else {
                            progress(1.0)
                            cont.resume(returning: outputURL)
                        }
                    }
                    return
                }

                do {
                    if audioFile == nil {
                        audioFile = try AVAudioFile(
                            forWriting: outputURL,
                            settings: pcm.format.settings,
                            commonFormat: pcm.format.commonFormat,
                            interleaved: pcm.format.isInterleaved
                        )
                    }
                    try audioFile?.write(from: pcm)
                    writtenFrames += Double(pcm.frameLength)
                    progress(min(0.95, writtenFrames / estimatedFrames))
                } catch {
                    once.run { cont.resume(throwing: error) }
                }
            }
        }
    }
}

/// Ensures a continuation resumes exactly once.
private final class ResumeOnce {
    private var done = false
    private let lock = NSLock()
    func run(_ block: () -> Void) {
        lock.lock(); defer { lock.unlock() }
        guard !done else { return }
        done = true
        block()
    }
}
