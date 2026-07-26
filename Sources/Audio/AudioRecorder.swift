import Foundation
import AVFoundation

/// Records a lossless WAV sample while publishing live metering for the waveform.
@MainActor
final class AudioRecorder: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var level: CGFloat = 0            // normalized 0...1 (current)
    @Published var levels: [CGFloat] = []        // rolling history for the waveform
    @Published var elapsed: TimeInterval = 0
    @Published var errorMessage: String?

    let minDuration: TimeInterval = 15
    let maxDuration: TimeInterval = 90

    private var recorder: AVAudioRecorder?
    private var meterTimer: Timer?
    private var outputURL: URL?

    var reachedMax: Bool { elapsed >= maxDuration }
    var meetsMinimum: Bool { elapsed >= minDuration }

    func start() {
        errorMessage = nil
        levels = []
        elapsed = 0
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("sample-\(UUID().uuidString).wav")
        outputURL = url

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false
        ]

        do {
            try AudioSessionManager.configureForRecording()
            let rec = try AVAudioRecorder(url: url, settings: settings)
            rec.isMeteringEnabled = true
            rec.delegate = self
            guard rec.record() else {
                errorMessage = "Couldn't start recording."
                return
            }
            recorder = rec
            isRecording = true
            startMetering()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Stops and returns the recorded file URL + duration, or nil on failure.
    @discardableResult
    func stop() -> (url: URL, duration: TimeInterval)? {
        stopMetering()
        recorder?.stop()
        isRecording = false
        let duration = elapsed
        guard let url = outputURL else { return nil }
        return (url, duration)
    }

    func cancel() {
        stopMetering()
        recorder?.stop()
        recorder?.deleteRecording()
        isRecording = false
        outputURL = nil
    }

    private func startMetering() {
        let t = Timer(timeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.sampleMeter() }
        }
        RunLoop.main.add(t, forMode: .common)
        meterTimer = t
    }

    private func stopMetering() {
        meterTimer?.invalidate()
        meterTimer = nil
    }

    private func sampleMeter() {
        guard let recorder, recorder.isRecording else { return }
        recorder.updateMeters()
        // averagePower is in dB, ~-60 (quiet) ... 0 (max). Map to 0...1.
        let db = recorder.averagePower(forChannel: 0)
        let normalized = CGFloat(max(0, (db + 55) / 55))
        level = normalized
        levels.append(normalized)
        if levels.count > 300 { levels.removeFirst(levels.count - 300) }
        elapsed = recorder.currentTime
        if elapsed >= maxDuration {
            _ = stop()
        }
    }
}

extension AudioRecorder: AVAudioRecorderDelegate {
    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        Task { @MainActor in
            self.isRecording = false
            self.stopMetering()
        }
    }
}
