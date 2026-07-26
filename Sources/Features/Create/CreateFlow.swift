import SwiftUI

/// Shared state for the record → confirm → document → generate wizard.
@MainActor
final class CreateFlow: ObservableObject {
    enum Step: Int, CaseIterable { case record, confirm, document, generate }

    @Published var step: Step = .record

    // Sample capture
    @Published var sampleTempURL: URL?
    @Published var sampleDuration: Double = 0
    @Published var profile: VoiceProfile?

    // Document
    @Published var documentText: String = ""
    @Published var documentName: String = "Document"

    func go(to step: Step) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { self.step = step }
    }

    func startOver() {
        sampleTempURL = nil
        sampleDuration = 0
        profile = nil
        documentText = ""
        documentName = "Document"
        go(to: .record)
    }

    /// After saving a narration: keep the confirmed voice, clear the document.
    func newDocument() {
        documentText = ""
        documentName = "Document"
        go(to: .document)
    }
}

struct CreateFlowView: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var library: LibraryStore
    @StateObject private var flow = CreateFlow()

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.ink.ignoresSafeArea()
                content
                    .padding(.horizontal, 20)
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.ink, for: .navigationBar)
            .toolbar {
                if flow.step != .record {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Start over") { flow.startOver() }
                            .foregroundStyle(Theme.linenMuted)
                    }
                }
            }
        }
        .onAppear(perform: prime)
    }

    @ViewBuilder private var content: some View {
        switch flow.step {
        case .record:   RecordSampleView(flow: flow)
        case .confirm:  ConfirmSampleView(flow: flow)
        case .document: LoadDocumentView(flow: flow)
        case .generate: GenerateView(flow: flow)
        }
    }

    private var title: String {
        switch flow.step {
        case .record:   return "Your voice"
        case .confirm:  return "Confirm sample"
        case .document: return "Load a document"
        case .generate: return "Create narration"
        }
    }

    /// If a saved profile already exists, skip straight to loading a document.
    private func prime() {
        if flow.step == .record, let active = library.profile(id: settings.activeProfileID) ?? library.profiles.first {
            flow.profile = active
            settings.activeProfileID = active.id.uuidString
            flow.go(to: .document)
        }
    }
}
