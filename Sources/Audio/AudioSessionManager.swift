import AVFoundation

enum AudioSessionManager {
    static func configureForRecording() throws {
        let session = AVAudioSession.sharedInstance()
        // Release any prior playback session (e.g. spoken instructions) so the
        // record category takes over cleanly.
        try? session.setActive(false, options: .notifyOthersOnDeactivation)
        try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
        try session.setActive(true)
    }

    static var recordPermissionGranted: Bool {
        AVAudioApplication.shared.recordPermission == .granted
    }

    static func configureForPlayback() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default)
        try session.setActive(true)
    }

    static func requestRecordPermission() async -> Bool {
        await withCheckedContinuation { cont in
            AVAudioApplication.requestRecordPermission { granted in
                cont.resume(returning: granted)
            }
        }
    }
}
