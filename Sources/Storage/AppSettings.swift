import Foundation
import SwiftUI
import AVFoundation

/// User-facing preferences + derived key state. Persisted to UserDefaults
/// (the API key itself lives in the Keychain).
@MainActor
final class AppSettings: ObservableObject {
    private let defaults = UserDefaults.standard

    @Published var hasCompletedOnboarding: Bool {
        didSet { defaults.set(hasCompletedOnboarding, forKey: "hasCompletedOnboarding") }
    }
    @Published var defaultEngine: NarrationEngine {
        didSet { defaults.set(defaultEngine.rawValue, forKey: "defaultEngine") }
    }
    @Published var defaultFormat: AudioFormat {
        didSet { defaults.set(defaultFormat.rawValue, forKey: "defaultFormat") }
    }
    @Published var defaultRate: Double {
        didSet { defaults.set(defaultRate, forKey: "defaultRate") }
    }
    @Published var defaultPitch: Double {
        didSet { defaults.set(defaultPitch, forKey: "defaultPitch") }
    }
    @Published var selectedVoiceID: String? {
        didSet { defaults.set(selectedVoiceID, forKey: "selectedVoiceID") }
    }
    @Published var activeProfileID: String? {
        didSet { defaults.set(activeProfileID, forKey: "activeProfileID") }
    }
    /// Set whenever the Keychain key changes so views update.
    @Published var hasElevenLabsKey: Bool

    /// Address of a self-hosted Coqui XTTS-v2 engine on the local network, e.g.
    /// "http://192.168.1.50:8787". Not a secret, just a LAN address.
    @Published var coquiServerURL: String? {
        didSet { defaults.set(coquiServerURL, forKey: "coquiServerURL") }
    }

    /// Maps VoiceProfile id -> ElevenLabs cloned voice id (so we don't re-clone).
    @Published var clonedVoiceIDs: [String: String] {
        didSet { defaults.set(clonedVoiceIDs, forKey: "clonedVoiceIDs") }
    }

    init() {
        hasCompletedOnboarding = defaults.bool(forKey: "hasCompletedOnboarding")
        defaultEngine = NarrationEngine(rawValue: defaults.string(forKey: "defaultEngine") ?? "") ?? .onDevice
        defaultFormat = AudioFormat(rawValue: defaults.string(forKey: "defaultFormat") ?? "") ?? .aac
        defaultRate = defaults.object(forKey: "defaultRate") as? Double ?? Double(AVUtterance.defaultRate)
        defaultPitch = defaults.object(forKey: "defaultPitch") as? Double ?? 1.0
        selectedVoiceID = defaults.string(forKey: "selectedVoiceID")
        activeProfileID = defaults.string(forKey: "activeProfileID")
        clonedVoiceIDs = defaults.dictionary(forKey: "clonedVoiceIDs") as? [String: String] ?? [:]
        hasElevenLabsKey = Keychain.loadAPIKey() != nil
        coquiServerURL = defaults.string(forKey: "coquiServerURL")

        // On-device can't be a "clone", so default engine stays on-device unless
        // the chosen clone engine is actually configured.
        if !isAvailable(defaultEngine) {
            defaultEngine = .onDevice
        }
    }

    var hasCoquiServer: Bool { !(coquiServerURL ?? "").isEmpty }

    /// Whether an engine is currently usable (on-device always is; clone engines
    /// need a key/server configured first).
    func isAvailable(_ engine: NarrationEngine) -> Bool {
        switch engine {
        case .onDevice:   return true
        case .elevenLabs: return hasElevenLabsKey
        case .coquiLocal: return hasCoquiServer
        }
    }

    func setAPIKey(_ key: String) {
        Keychain.saveAPIKey(key)
        hasElevenLabsKey = true
    }

    func clearAPIKey() {
        Keychain.deleteAPIKey()
        hasElevenLabsKey = false
        if defaultEngine == .elevenLabs { defaultEngine = .onDevice }
    }

    var apiKey: String? { Keychain.loadAPIKey() }
}

enum AVUtterance {
    static let defaultRate: Float = AVSpeechUtteranceDefaultSpeechRate
}
