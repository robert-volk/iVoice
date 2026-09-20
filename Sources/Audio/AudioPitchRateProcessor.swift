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
        let sourceFrameCount = sourceFile.length

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

        // A pure player-fed offline graph (no live input node) never actually
        // reports .insufficientDataFromInputNode once the file is drained -- it
        // just keeps emitting .success with silence forever. So termination is
        // driven by the player's own completion signal instead, not the render
        // status. .dataPlayedBack fires only once the scheduled audio has been
        // pushed all the way through the render graph (not just read from disk).
        let finished = CompletionFlag()
        player.scheduleFile(sourceFile, at: nil, completionCallbackType: .dataPlayedBack) { _ in
            finished.set()
        }
        player.play()

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("pitchrate-\(UUID().uuidString).caf")
        let outputFile = try AVAudioFile(forWriting: outputURL, settings: format.settings)

        guard let buffer = AVAudioPCMBuffer(pcmFormat: engine.manualRenderingFormat,
                                             frameCapacity: engine.manualRenderingMaximumFrameCount) else {
            throw AudioPitchRateError.processingFailed
        }

        // Expected output length shrinks/grows with rate (rate=2.0 -> half the
        // frames). Add slack for the time-pitch unit's internal latency/tail.
        let expectedOutputFrames = Double(sourceFrameCount) / Double(timePitch.rate)
        let maxFrames = AVAudioFramePosition(expectedOutputFrames * 1.5) + AVAudioFramePosition(format.sampleRate * 2)
        var framesRendered: AVAudioFramePosition = 0

        // Absolute backstop independent of frame progress: .cannotDoInCurrentContext
        // retries via `continue` don't advance framesRendered, so a persistent stall
        // there wouldn't be caught by the frame cap alone. This guarantees the loop
        // can never hang indefinitely no matter which status keeps coming back.
        let deadline = Date().addingTimeInterval(60)

        renderLoop: while !finished.isSet && framesRendered < maxFrames && Date() < deadline {
            let status = try engine.renderOffline(engine.manualRenderingMaximumFrameCount, to: buffer)
            switch status {
            case .success:
                try outputFile.write(from: buffer)
                framesRendered += AVAudioFramePosition(buffer.frameLength)
            case .insufficientDataFromInputNode:
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

        guard framesRendered > 0 else {
            throw AudioPitchRateError.processingFailed
        }
        return outputURL
    }
}

/// Thread-safe completion flag: AVAudioPlayerNode's completion handler fires on
/// an internal audio thread, not whichever thread is running the render loop.
private final class CompletionFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var done = false

    func set() {
        lock.lock(); done = true; lock.unlock()
    }

    var isSet: Bool {
        lock.lock(); defer { lock.unlock() }
        return done
    }
}
