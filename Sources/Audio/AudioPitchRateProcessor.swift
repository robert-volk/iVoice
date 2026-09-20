import Foundation
import AVFoundation

enum AudioPitchRateError: LocalizedError {
    case processingFailed
    var errorDescription: String? { "Couldn't adjust the pitch/rate of the generated audio." }
}

/// Applies a rate (speed) and pitch adjustment to an already-synthesized audio file,
/// using AVAudioEngine's offline rendering with a real AVAudioUnitTimePitch DSP unit.
///
/// On-device narration bakes rate/pitch into AVSpeechUtterance directly at synthesis
/// time, which sounds better, so it never needs this. Cloned voices (ElevenLabs,
/// Coqui) don't take rate/pitch as an input at all, so this is the only way to offer
/// the same two controls for them.
enum AudioPitchRateProcessor {

    /// `rateMultiplier`: 1.0 = unchanged speed, 2.0 = double speed, 0.5 = half speed.
    /// `pitchMultiplier`: 1.0 = unchanged pitch (same convention as AVSpeechUtterance.pitchMultiplier).
    static func apply(rateMultiplier: Float, pitchMultiplier: Float, to sourceURL: URL) async throws -> URL {
        let isNeutral = abs(rateMultiplier - 1.0) < 0.001 && abs(pitchMultiplier - 1.0) < 0.001
        if isNeutral { return sourceURL }

        return try await Task.detached(priority: .userInitiated) {
            try render(rateMultiplier: rateMultiplier, pitchMultiplier: pitchMultiplier, sourceURL: sourceURL)
        }.value
    }

    /// Blocking offline render -- must run off the main/actor thread.
    private static func render(rateMultiplier: Float, pitchMultiplier: Float, sourceURL: URL) throws -> URL {
        let sourceFile = try AVAudioFile(forReading: sourceURL)
        let format = sourceFile.processingFormat

        let engine = AVAudioEngine()
        let player = AVAudioPlayerNode()
        let timePitch = AVAudioUnitTimePitch()
        timePitch.rate = min(4.0, max(0.25, rateMultiplier))
        timePitch.pitch = 1200 * log2f(min(4.0, max(0.1, pitchMultiplier))) // cents = 1200 * log2(ratio)

        engine.attach(player)
        engine.attach(timePitch)
        engine.connect(player, to: timePitch, format: format)
        engine.connect(timePitch, to: engine.mainMixerNode, format: format)

        try engine.enableManualRenderingMode(.offline, format: format, maximumFrameCount: 4096)
        try engine.start()
        player.scheduleFile(sourceFile, at: nil)
        player.play()

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("pitchrate-\(UUID().uuidString).caf")
        let outputFile = try AVAudioFile(forWriting: outputURL, settings: format.settings)

        guard let buffer = AVAudioPCMBuffer(pcmFormat: engine.manualRenderingFormat,
                                             frameCapacity: engine.manualRenderingMaximumFrameCount) else {
            throw AudioPitchRateError.processingFailed
        }

        renderLoop: while true {
            let status = try engine.renderOffline(engine.manualRenderingMaximumFrameCount, to: buffer)
            switch status {
            case .success:
                try outputFile.write(from: buffer)
            case .insufficientDataFromInputNode:
                // Player has no more scheduled audio to give us -- everything real
                // was already flushed via the .success branch above. Done.
                break renderLoop
            case .cannotDoInCurrentContext:
                continue renderLoop
            case .error:
                throw AudioPitchRateError.processingFailed
            @unknown default:
                throw AudioPitchRateError.processingFailed
            }
        }

        engine.stop()
        return outputURL
    }
}
