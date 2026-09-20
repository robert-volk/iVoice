import Foundation

enum CoquiError: LocalizedError {
    case invalidServerURL
    case missingSample
    case http(Int, String)
    case badResponse
    case emptyAudio

    var errorDescription: String? {
        switch self {
        case .invalidServerURL:
            return "Enter your Coqui engine's address in Settings (e.g. http://192.168.1.50:8787)."
        case .missingSample:
            return "No confirmed voice sample to clone from."
        case .http(let code, let msg):
            return "Coqui engine error \(code): \(msg)"
        case .badResponse:
            return "Unexpected response from the Coqui engine."
        case .emptyAudio:
            return "The Coqui engine returned no audio."
        }
    }
}

/// Real cloning via a self-hosted Coqui XTTS-v2 engine (see the sibling VoxClone/engine
/// project) running on the user's own PC. Nothing goes to any third-party cloud — the
/// trade-off is that a small local server must be running and reachable on the same
/// network as this phone.
struct CoquiVoiceProvider: VoiceProvider {
    let engine: NarrationEngine = .coquiLocal
    let requiresNetwork = true

    let serverURLString: String
    let sampleURL: (VoiceProfile) -> URL

    func availableVoices() async -> [VoiceOption] {
        [VoiceOption(id: "cloned", name: "Your cloned voice", engine: .coquiLocal, language: nil)]
    }

    /// Lightweight reachability check used by Settings.
    static func validate(serverURLString: String) async -> Bool {
        guard let url = baseURL(serverURLString)?.appendingPathComponent("health") else { return false }
        guard let (_, response) = try? await URLSession.shared.data(from: url),
              let http = response as? HTTPURLResponse else { return false }
        return http.statusCode == 200
    }

    func synthesize(request: SynthesisRequest,
                    progress: @escaping (Double) -> Void) async throws -> URL {
        guard let base = Self.baseURL(serverURLString) else { throw CoquiError.invalidServerURL }
        guard let profile = request.profile else { throw CoquiError.missingSample }
        progress(0.05)

        try await uploadSample(base: base, profile: profile)
        progress(0.3)

        let audioURL = try await speak(base: base, text: request.text)
        progress(1.0)
        return audioURL
    }

    // MARK: - Steps

    private func uploadSample(base: URL, profile: VoiceProfile) async throws {
        let sample = sampleURL(profile)
        guard FileManager.default.fileExists(atPath: sample.path) else {
            throw CoquiError.missingSample
        }
        var req = URLRequest(url: base.appendingPathComponent("clone"))
        req.httpMethod = "POST"
        req.setValue("audio/wav", forHTTPHeaderField: "Content-Type")

        let data = try Data(contentsOf: sample)
        let (respData, response) = try await URLSession.shared.upload(for: req, from: data)
        try Self.checkHTTP(response, respData)
    }

    private func speak(base: URL, text: String) async throws -> URL {
        var req = URLRequest(url: base.appendingPathComponent("speak"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: ["text": text, "language": "en"])

        let (data, response) = try await URLSession.shared.data(for: req)
        try Self.checkHTTP(response, data)

        guard let wav = Self.assembleWAV(fromFramedStream: data), !wav.isEmpty else {
            throw CoquiError.emptyAudio
        }

        let out = FileManager.default.temporaryDirectory
            .appendingPathComponent("coqui-\(UUID().uuidString).wav")
        try wav.write(to: out)
        return out
    }

    // MARK: - Wire framing / WAV assembly
    //
    // The engine streams one clip per sentence as [4-byte big-endian length][WAV bytes].
    // iVoice doesn't need incremental playback (unlike a live-reading app), so it just
    // waits for the whole response and concatenates every clip's PCM data into one WAV
    // using the first clip's format.

    private struct WAVFormat {
        var channels: UInt16
        var sampleRate: UInt32
        var bitsPerSample: UInt16
    }

    private static func assembleWAV(fromFramedStream data: Data) -> Data? {
        let bytes = [UInt8](data)
        var offset = 0
        var format: WAVFormat?
        var pcm = Data()

        while offset + 4 <= bytes.count {
            let length = (Int(bytes[offset]) << 24) | (Int(bytes[offset + 1]) << 16)
                       | (Int(bytes[offset + 2]) << 8) | Int(bytes[offset + 3])
            offset += 4
            guard length > 0, offset + length <= bytes.count else { break }

            let clip = data.subdata(in: (data.startIndex + offset)..<(data.startIndex + offset + length))
            offset += length

            guard let parsed = parseWAV(clip) else { continue }
            if format == nil { format = parsed.format }
            pcm.append(parsed.pcm)
        }

        guard let format else { return nil }
        return writeWAV(pcm: pcm, format: format)
    }

    private static func parseWAV(_ data: Data) -> (format: WAVFormat, pcm: Data)? {
        let bytes = [UInt8](data)
        guard bytes.count > 12,
              bytes[0...3].elementsEqual(Array("RIFF".utf8)),
              bytes[8...11].elementsEqual(Array("WAVE".utf8))
        else { return nil }

        var idx = 12
        var format: WAVFormat?
        var pcm: Data?

        while idx + 8 <= bytes.count {
            let chunkID = String(decoding: bytes[idx..<idx + 4], as: UTF8.self)
            let chunkSize = Int(readUInt32LE(bytes, idx + 4))
            let bodyStart = idx + 8
            guard bodyStart + chunkSize <= bytes.count else { break }

            if chunkID == "fmt " {
                let channels = readUInt16LE(bytes, bodyStart + 2)
                let sampleRate = readUInt32LE(bytes, bodyStart + 4)
                let bitsPerSample = readUInt16LE(bytes, bodyStart + 14)
                format = WAVFormat(channels: channels, sampleRate: sampleRate, bitsPerSample: bitsPerSample)
            } else if chunkID == "data" {
                pcm = data.subdata(in: (data.startIndex + bodyStart)..<(data.startIndex + bodyStart + chunkSize))
            }

            idx = bodyStart + chunkSize + (chunkSize % 2) // chunks are word-aligned
        }

        guard let format, let pcm else { return nil }
        return (format, pcm)
    }

    private static func writeWAV(pcm: Data, format: WAVFormat) -> Data {
        var header = Data()
        let byteRate = format.sampleRate * UInt32(format.channels) * UInt32(format.bitsPerSample / 8)
        let blockAlign = format.channels * (format.bitsPerSample / 8)
        let dataSize = UInt32(pcm.count)
        let riffSize = 36 + dataSize

        func appendString(_ s: String) { header.append(contentsOf: Array(s.utf8)) }
        func appendU32(_ v: UInt32) { withUnsafeBytes(of: v.littleEndian) { header.append(contentsOf: $0) } }
        func appendU16(_ v: UInt16) { withUnsafeBytes(of: v.littleEndian) { header.append(contentsOf: $0) } }

        appendString("RIFF"); appendU32(riffSize); appendString("WAVE")
        appendString("fmt "); appendU32(16)
        appendU16(1) // PCM
        appendU16(format.channels)
        appendU32(format.sampleRate)
        appendU32(byteRate)
        appendU16(blockAlign)
        appendU16(format.bitsPerSample)
        appendString("data"); appendU32(dataSize)

        return header + pcm
    }

    private static func readUInt16LE(_ bytes: [UInt8], _ offset: Int) -> UInt16 {
        UInt16(bytes[offset]) | (UInt16(bytes[offset + 1]) << 8)
    }
    private static func readUInt32LE(_ bytes: [UInt8], _ offset: Int) -> UInt32 {
        UInt32(bytes[offset]) | (UInt32(bytes[offset + 1]) << 8)
            | (UInt32(bytes[offset + 2]) << 16) | (UInt32(bytes[offset + 3]) << 24)
    }

    // MARK: - URL / HTTP helpers

    private static func baseURL(_ s: String) -> URL? {
        var trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if !trimmed.contains("://") { trimmed = "http://" + trimmed }
        if !trimmed.hasSuffix("/") { trimmed += "/" }
        return URL(string: trimmed)
    }

    private static func checkHTTP(_ response: URLResponse, _ data: Data) throws {
        guard let http = response as? HTTPURLResponse else { throw CoquiError.badResponse }
        guard (200..<300).contains(http.statusCode) else {
            let msg = String(data: data, encoding: .utf8) ?? ""
            throw CoquiError.http(http.statusCode, String(msg.prefix(200)))
        }
    }
}
