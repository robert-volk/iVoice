import Foundation
import PDFKit

enum DocumentError: LocalizedError {
    case unsupported(String)
    case empty
    case unreadable

    var errorDescription: String? {
        switch self {
        case .unsupported(let ext): return "iVoice can't read .\(ext) files yet. Try PDF, txt, md, or rtf."
        case .empty: return "That document didn't contain any readable text."
        case .unreadable: return "Couldn't read that file."
        }
    }
}

/// Extracts plain text from a document URL. Handles PDF, txt/md, rtf; best-effort
/// otherwise. Fails honestly rather than silently.
enum DocumentTextExtractor {
    static func extractText(from url: URL) throws -> String {
        let needsScope = url.startAccessingSecurityScopedResource()
        defer { if needsScope { url.stopAccessingSecurityScopedResource() } }

        let ext = url.pathExtension.lowercased()
        let text: String

        switch ext {
        case "pdf":
            text = try pdfText(url)
        case "txt", "md", "markdown", "text", "":
            text = try plainText(url)
        case "rtf":
            text = try rtfText(url)
        default:
            // Best effort: try as UTF-8 text; if it looks binary, give up honestly.
            if let attempt = try? plainText(url), !attempt.isEmpty {
                text = attempt
            } else {
                throw DocumentError.unsupported(ext)
            }
        }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw DocumentError.empty }
        return trimmed
    }

    private static func pdfText(_ url: URL) throws -> String {
        guard let doc = PDFDocument(url: url) else { throw DocumentError.unreadable }
        var out = ""
        for i in 0..<doc.pageCount {
            if let page = doc.page(at: i), let s = page.string {
                out += s + "\n\n"
            }
        }
        return out
    }

    private static func plainText(_ url: URL) throws -> String {
        if let s = try? String(contentsOf: url, encoding: .utf8) { return s }
        if let s = try? String(contentsOf: url, encoding: .isoLatin1) { return s }
        throw DocumentError.unreadable
    }

    private static func rtfText(_ url: URL) throws -> String {
        let data = try Data(contentsOf: url)
        let attributed = try NSAttributedString(
            data: data,
            options: [.documentType: NSAttributedString.DocumentType.rtf],
            documentAttributes: nil
        )
        return attributed.string
    }
}
