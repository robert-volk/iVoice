import Foundation

/// MP3 encoding hook.
///
/// iOS cannot encode MP3 natively, so on-device narration cannot be written to
/// MP3 without a bundled encoder. To enable it:
///   1. Add a LAME (LGPL) Swift package — see the commented block in `project.yml`.
///   2. Implement `encode(pcmURL:to:)` against it and set `isAvailable = true`.
///
/// Note: audio produced by the ElevenLabs engine is already MP3, so MP3 export
/// works there regardless of this encoder (the file is copied, not re-encoded).
enum Mp3Encoder {
    /// Flip to `true` once a real LAME-backed implementation is provided below.
    static let isAvailable = false

    static func encode(pcmURL: URL, to outputURL: URL) throws {
        // Reference implementation outline (requires LAME):
        //
        //   let file = try AVAudioFile(forReading: pcmURL)
        //   let lame = lame_init()
        //   lame_set_in_samplerate(lame, Int32(file.fileFormat.sampleRate))
        //   lame_set_num_channels(lame, Int32(file.fileFormat.channelCount))
        //   lame_set_quality(lame, 2)
        //   lame_init_params(lame)
        //   // read PCM frames -> lame_encode_buffer* -> append to outputURL
        //   lame_close(lame)
        //
        throw AudioExportError.mp3Unavailable
    }
}
