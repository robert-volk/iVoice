import Foundation
import AVFoundation

/// Speaks on-screen instructions aloud in a natural female voice.
@MainActor
final class InstructionSpeaker: ObservableObject {
    @Published var isSpeaking = false

    private let synthesizer = AVSpeechSynthesizer()
    private let delegateProxy = DelegateProxy()

    init() {
        synthesizer.delegate = delegateProxy
        delegateProxy.onChange = { [weak self] speaking in
            Task { @MainActor in self?.isSpeaking = speaking }
        }
    }

    func speak(_ text: String) {
        try? AudioSessionManager.configureForPlayback()
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = OnDeviceVoiceProvider.preferredFemaleInstructionVoice()
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.96
        utterance.pitchMultiplier = 1.0
        synthesizer.speak(utterance)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }

    private final class DelegateProxy: NSObject, AVSpeechSynthesizerDelegate {
        var onChange: ((Bool) -> Void)?
        func speechSynthesizer(_ s: AVSpeechSynthesizer, didStart u: AVSpeechUtterance) { onChange?(true) }
        func speechSynthesizer(_ s: AVSpeechSynthesizer, didFinish u: AVSpeechUtterance) { onChange?(false) }
        func speechSynthesizer(_ s: AVSpeechSynthesizer, didCancel u: AVSpeechUtterance) { onChange?(false) }
    }
}
