import Foundation

enum ElevenLabsError: LocalizedError {
    case missingSample
    case http(Int, String)
    case badResponse
    case noVoiceID

    var errorDescription: String? {
        switch self {
        case .missingSample: return "No confirmed voice sample to clone from."
        case .http(let code, let msg): return "ElevenLabs error \(code): \(msg)"
        case .badResponse: return "Unexpected response from ElevenLabs."
        case .noVoiceID: return "Couldn't create a cloned voice."
        }
    }
}

/// Real cloning via ElevenLabs. Only used when the user has entered an API key
/// and selected this engine. Uploads the voice sample + document text.
struct ElevenLabsVoiceProvider: VoiceProvider {
    let engine: NarrationEngine = .elevenLabs
    let requiresNetwork = true

    let apiKey: String
    /// Resolves/caches the cloned voice id for a given profile.
    var cachedVoiceID: (VoiceProfile) -> String?
    var storeVoiceID: (VoiceProfile, String) -> Void
    var sampleURL: (VoiceProfile) -> URL

    private let base = URL(string: "https://api.elevenlabs.io/v1")!

    func availableVoices() async -> [VoiceOption] {
        // The relevant "voice" here is the user's cloned voice.
        [VoiceOption(id: "cloned", name: "Your cloned voice", engine: .elevenLabs, language: nil)]
    }

    /// Lightweight key check used by Settings.
    static func validate(apiKey: String) async -> Bool {
        var req = URLRequest(url: URL(string: "https://api.elevenlabs.io/v1/user")!)
        req.setValue(apiKey, forHTTPHeaderField: "xi-api-key")
        guard let (_, response) = try? await URLSession.shared.data(for: req),
              let http = response as? HTTPURLResponse else { return false }
        return http.statusCode == 200
    }

    func synthesize(request: SynthesisRequest,
                    progress: @escaping (Double) -> Void) async throws -> URL {
        guard let profile = request.profile else { throw ElevenLabsError.missingSample }
        progress(0.05)

        let voiceID = try await resolveVoiceID(for: profile)
        progress(0.45)

        let audioURL = try await textToSpeech(voiceID: voiceID, text: request.text)
        progress(1.0)
        return audioURL
    }

    // MARK: - Cloning

    private func resolveVoiceID(for profile: VoiceProfile) async throws -> String {
        if let cached = cachedVoiceID(profile) { return cached }

        let sample = sampleURL(profile)
        guard FileManager.default.fileExists(atPath: sample.path) else {
            throw ElevenLabsError.missingSample
        }

        var req = URLRequest(url: base.appendingPathComponent("voices/add"))
        req.httpMethod = "POST"
        req.setValue(apiKey, forHTTPHeaderField: "xi-api-key")

        let boundary = "Boundary-\(UUID().uuidString)"
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        func appendField(_ name: String, _ value: String) {
            body.append("--\(boundary)\r\n")
            body.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n")
            body.append("\(value)\r\n")
        }
        appendField("name", "iVoice – \(profile.name)")

        let sampleData = try Data(contentsOf: sample)
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"files\"; filename=\"sample.wav\"\r\n")
        body.append("Content-Type: audio/wav\r\n\r\n")
        body.append(sampleData)
        body.append("\r\n")
        body.append("--\(boundary)--\r\n")

        let (data, response) = try await URLSession.shared.upload(for: req, from: body)
        try Self.checkHTTP(response, data)

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let voiceID = json["voice_id"] as? String else {
            throw ElevenLabsError.noVoiceID
        }
        storeVoiceID(profile, voiceID)
        return voiceID
    }

    // MARK: - TTS

    private func textToSpeech(voiceID: String, text: String) async throws -> URL {
        var comps = URLComponents(url: base.appendingPathComponent("text-to-speech/\(voiceID)"),
                                  resolvingAgainstBaseURL: false)!
        comps.queryItems = [URLQueryItem(name: "output_format", value: "mp3_44100_128")]

        var req = URLRequest(url: comps.url!)
        req.httpMethod = "POST"
        req.setValue(apiKey, forHTTPHeaderField: "xi-api-key")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("audio/mpeg", forHTTPHeaderField: "Accept")

        let payload: [String: Any] = [
            "text": text,
            "model_id": "eleven_multilingual_v2",
            "voice_settings": ["stability": 0.5, "similarity_boost": 0.75]
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await URLSession.shared.data(for: req)
        try Self.checkHTTP(response, data)

        let out = FileManager.default.temporaryDirectory
            .appendingPathComponent("eleven-\(UUID().uuidString).mp3")
        try data.write(to: out)
        return out
    }

    private static func checkHTTP(_ response: URLResponse, _ data: Data) throws {
        guard let http = response as? HTTPURLResponse else { throw ElevenLabsError.badResponse }
        guard (200..<300).contains(http.statusCode) else {
            let msg = String(data: data, encoding: .utf8) ?? ""
            throw ElevenLabsError.http(http.statusCode, String(msg.prefix(200)))
        }
    }
}

private extension Data {
    mutating func append(_ string: String) {
        if let d = string.data(using: .utf8) { append(d) }
    }
}
