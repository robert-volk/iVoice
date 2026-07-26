import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct LoadDocumentView: View {
    @ObservedObject var flow: CreateFlow
    @State private var showImporter = false
    @State private var importError: String?

    private let importTypes: [UTType] = [.pdf, .plainText, .rtf, .text, UTType("net.daringfireball.markdown") ?? .plainText]

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                voiceBanner

                HStack(spacing: 12) {
                    Button {
                        showImporter = true
                    } label: {
                        Label("Import file", systemImage: "doc.badge.plus")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(SecondaryButtonStyle())

                    Button {
                        if let pasted = UIPasteboard.general.string, !pasted.isEmpty {
                            flow.documentText = pasted
                            flow.documentName = "Pasted text"
                        } else {
                            importError = "Clipboard is empty."
                        }
                    } label: {
                        Label("Paste text", systemImage: "doc.on.clipboard")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }

                editorCard

                if let importError {
                    Text(importError).font(.footnote).foregroundStyle(Theme.danger)
                }

                Button("Continue") { flow.go(to: .generate) }
                    .buttonStyle(PrimaryButtonStyle(enabled: !trimmed.isEmpty))
                    .disabled(trimmed.isEmpty)
            }
            .padding(.vertical, 12)
        }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: importTypes) { result in
            handleImport(result)
        }
    }

    private var voiceBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "mic.fill").foregroundStyle(Theme.emerald)
            Text("Voice: \(flow.profile?.name ?? "My Voice")")
                .font(.subheadline).foregroundStyle(Theme.linen)
            Spacer()
            Button("Change") { flow.go(to: .record) }
                .font(.footnote).foregroundStyle(Theme.emerald)
        }
        .studioCard()
    }

    private var editorCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Document text")
                    .font(.headline).foregroundStyle(Theme.linen)
                Spacer()
                Text("\(wordCount) words · ~\(estimatedMinutes) min")
                    .font(.footnote.monospaced()).foregroundStyle(Theme.linenMuted)
            }
            Text("Edit to fix any parsing artifacts before narrating.")
                .font(.caption).foregroundStyle(Theme.linenMuted)

            TextEditor(text: $flow.documentText)
                .frame(minHeight: 240)
                .scrollContentBackground(.hidden)
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 10).fill(Theme.ink))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.inkLine))
                .foregroundStyle(Theme.linen)
                .font(.body)
        }
        .studioCard()
    }

    private var trimmed: String {
        flow.documentText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    private var wordCount: Int {
        trimmed.isEmpty ? 0 : trimmed.split { $0 == " " || $0.isNewline }.count
    }
    private var estimatedMinutes: Int {
        max(1, Int((Double(wordCount) / 150.0).rounded(.up)))
    }

    private func handleImport(_ result: Result<URL, Error>) {
        importError = nil
        switch result {
        case .success(let url):
            do {
                let text = try DocumentTextExtractor.extractText(from: url)
                flow.documentText = text
                flow.documentName = url.deletingPathExtension().lastPathComponent
            } catch {
                importError = error.localizedDescription
            }
        case .failure(let error):
            importError = error.localizedDescription
        }
    }
}
