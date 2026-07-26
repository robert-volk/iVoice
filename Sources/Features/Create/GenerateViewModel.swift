import Foundation
import SwiftUI

@MainActor
final class GenerateViewModel: ObservableObject {
    enum Phase: Equatable {
        case idle
        case generating(Double)
        case ready
        case failed(String)
    }

    @Published var phase: Phase = .idle
    @Published var onDeviceVoices: [VoiceOption] = []

    // Result
    @Published var outputURL: URL?
    @Published var producedFormat: AudioFormat = .aac
    @Published var producedDuration: Double = 0
    @Published var fellBackToAAC = false

    func loadVoices() async {
        onDeviceVoices = await OnDeviceVoiceProvider().availableVoices()
    }

    func generate(text: String,
                  profile: VoiceProfile?,
                  engine: NarrationEngine,
                  voiceID: String,
                  rate: Double,
                  pitch: Double,
                  format: AudioFormat,
                  settings: AppSettings,
                  library: LibraryStore) async {

        phase = .generating(0)
        fellBackToAAC = false
        outputURL = nil

        do {
            let provider = makeProvider(engine: engine, settings: settings, library: library)
            let request = SynthesisRequest(
                text: text,
                voiceID: voiceID,
                profile: profile,
                rate: Float(rate),
                pitch: Float(pitch)
            )

            let source = try await provider.synthesize(request: request) { [weak self] p in
                Task { @MainActor in
                    // Reserve the last 15% for the export step.
                    self?.phase = .generating(min(0.85, p * 0.85))
                }
            }

            phase = .generating(0.9)

            let outName = "narration-\(UUID().uuidString).\(format.fileExtension)"
            let out = FileManager.default.temporaryDirectory.appendingPathComponent(outName)
            let actual = try await AudioExporter.export(source: source, to: format, output: resolvedExportURL(out, format))

            let finalURL = resolvedExportURL(out, actual)
            let duration = await AudioExporter.duration(of: finalURL)

            outputURL = finalURL
            producedFormat = actual
            producedDuration = duration
            fellBackToAAC = (format == .mp3 && actual == .aac)
            phase = .ready
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    func save(documentName: String,
              engine: NarrationEngine,
              voiceName: String,
              library: LibraryStore) -> Narration? {
        guard let outputURL else { return nil }
        return try? library.addNarration(
            title: documentName,
            sourceName: documentName,
            engine: engine,
            voiceName: voiceName,
            format: producedFormat,
            tempAudioURL: outputURL,
            duration: producedDuration
        )
    }

    // MARK: - Helpers

    private func makeProvider(engine: NarrationEngine, settings: AppSettings, library: LibraryStore) -> VoiceProvider {
        switch engine {
        case .onDevice:
            return OnDeviceVoiceProvider()
        case .elevenLabs:
            return ElevenLabsVoiceProvider(
                apiKey: settings.apiKey ?? "",
                cachedVoiceID: { settings.clonedVoiceIDs[$0.id.uuidString] },
                storeVoiceID: { profile, voiceID in settings.clonedVoiceIDs[profile.id.uuidString] = voiceID },
                sampleURL: { library.sampleURL(for: $0) }
            )
        }
    }

    /// If MP3 wasn't available the exporter writes .m4a — keep the extension in sync.
    private func resolvedExportURL(_ base: URL, _ format: AudioFormat) -> URL {
        base.deletingPathExtension().appendingPathExtension(format.fileExtension)
    }
}
