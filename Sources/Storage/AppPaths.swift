import Foundation

/// Central place for on-disk locations. Audio lives in Documents; metadata JSON
/// lives in Application Support.
enum AppPaths {
    static let fm = FileManager.default

    static var documents: URL {
        fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    static var appSupport: URL {
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        ensure(base)
        return base
    }

    static var samples: URL {
        let url = documents.appendingPathComponent("Samples", isDirectory: true)
        ensure(url)
        return url
    }

    static var narrations: URL {
        let url = documents.appendingPathComponent("Narrations", isDirectory: true)
        ensure(url)
        return url
    }

    static func sampleURL(_ fileName: String) -> URL { samples.appendingPathComponent(fileName) }
    static func narrationURL(_ fileName: String) -> URL { narrations.appendingPathComponent(fileName) }

    private static func ensure(_ url: URL) {
        if !fm.fileExists(atPath: url.path) {
            try? fm.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }
}
