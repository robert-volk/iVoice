import Foundation
import AVFoundation

/// Simple AVAudioPlayer wrapper that publishes progress for the scrubber.
@MainActor
final class AudioPlayerController: NSObject, ObservableObject {
    @Published var isPlaying = false
    @Published var progress: Double = 0     // 0...1
    @Published var duration: Double = 0
    @Published var currentTime: Double = 0

    private var player: AVAudioPlayer?
    private var timer: Timer?

    func load(url: URL) {
        stop()
        do {
            try AudioSessionManager.configureForPlayback()
            let p = try AVAudioPlayer(contentsOf: url)
            p.delegate = self
            p.prepareToPlay()
            player = p
            duration = p.duration
            currentTime = 0
            progress = 0
        } catch {
            player = nil
        }
    }

    func togglePlay() {
        guard let player else { return }
        if player.isPlaying {
            player.pause()
            isPlaying = false
            stopTimer()
        } else {
            player.play()
            isPlaying = true
            startTimer()
        }
    }

    func seek(toFraction f: Double) {
        guard let player else { return }
        let t = max(0, min(1, f)) * player.duration
        player.currentTime = t
        currentTime = t
        progress = player.duration > 0 ? t / player.duration : 0
    }

    func stop() {
        player?.stop()
        player = nil
        isPlaying = false
        stopTimer()
        progress = 0
        currentTime = 0
    }

    private func startTimer() {
        stopTimer()
        let t = Timer(timeInterval: 0.03, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        guard let player else { return }
        currentTime = player.currentTime
        progress = player.duration > 0 ? player.currentTime / player.duration : 0
    }
}

extension AudioPlayerController: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.isPlaying = false
            self.progress = 1
            self.stopTimer()
        }
    }
}
