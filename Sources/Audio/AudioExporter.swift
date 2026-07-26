import Foundation
import AVFoundation

enum AudioExportError: LocalizedError {
    case mp3Unavailable
    case conversionFailed

    var errorDescription: String? {
        switch self {
        case .mp3Unavailable:
            return "MP3 export needs the LAME encoder (see README). Saved as AAC instead."
        case .conversionFailed:
            return "Couldn't convert the audio."
        }
    }
}

/// Converts a rendered audio file into the user's chosen container.
enum AudioExporter {

    /// Whether MP3 can be produced for a given source without falling back.
    static func canExportMP3(sourceIsMP3: Bool) -> Bool {
        sourceIsMP3 || Mp3Encoder.isAvailable
    }

    /// Export `source` to `output` in `format`. Returns the format actually written
    /// (may differ from the request if MP3 wasn't available and we fell back to AAC).
    @discardableResult
    static func export(source: URL, to format: AudioFormat, output: URL) async throws -> AudioFormat {
        try? FileManager.default.removeItem(at: output)

        switch format {
        case .aac:
            try await exportM4A(source: source, output: output)
            return .aac

        case .mp3:
            let sourceIsMP3 = source.pathExtension.lowercased() == "mp3"
            if sourceIsMP3 {
                try FileManager.default.copyItem(at: source, to: output)
                return .mp3
            }
            if Mp3Encoder.isAvailable {
                try Mp3Encoder.encode(pcmURL: source, to: output)
                return .mp3
            }
            // Honest fallback: no LAME → write AAC and report it.
            let aacOutput = output.deletingPathExtension().appendingPathExtension("m4a")
            try await exportM4A(source: source, output: aacOutput)
            return .aac
        }
    }

    private static func exportM4A(source: URL, output: URL) async throws {
        let asset = AVURLAsset(url: source)
        guard let session = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            throw AudioExportError.conversionFailed
        }
        session.outputURL = output
        session.outputFileType = .m4a

        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            session.exportAsynchronously {
                switch session.status {
                case .completed: cont.resume()
                default:         cont.resume(throwing: session.error ?? AudioExportError.conversionFailed)
                }
            }
        }
    }

    /// Duration in seconds of an audio file.
    static func duration(of url: URL) async -> Double {
        let asset = AVURLAsset(url: url)
        if let d = try? await asset.load(.duration) {
            return CMTimeGetSeconds(d)
        }
        return 0
    }
}
