import SwiftUI

struct NarrationDetailView: View {
    @EnvironmentObject var library: LibraryStore
    @Environment(\.dismiss) private var dismiss
    let narration: Narration

    @StateObject private var player = AudioPlayerController()
    @State private var showShare = false
    @State private var showRename = false
    @State private var newTitle = ""

    var body: some View {
        ZStack {
            Theme.ink.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 20) {
                    header
                    PlayerBar(player: player, url: library.audioURL(for: narration))
                        .studioCard()
                    metadata
                    actions
                }
                .padding(20)
            }
        }
        .navigationTitle(narration.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.ink, for: .navigationBar)
        .sheet(isPresented: $showShare) {
            ShareSheet(items: [library.audioURL(for: narration)])
        }
        .alert("Rename narration", isPresented: $showRename) {
            TextField("Title", text: $newTitle)
            Button("Save") {
                let t = newTitle.trimmingCharacters(in: .whitespaces)
                if !t.isEmpty { library.rename(narration, to: t) }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            Image(systemName: "waveform")
                .font(.system(size: 54)).foregroundStyle(Theme.emerald)
                .shadow(color: Theme.emeraldGlow, radius: 16)
            Text(narration.engine.isClone ? "Cloned voice" : "System voice")
                .font(.subheadline).foregroundStyle(Theme.linenMuted)
        }
        .padding(.top, 8)
    }

    private var metadata: some View {
        VStack(spacing: 10) {
            row("Voice", narration.voiceName)
            row("Engine", narration.engine.displayName)
            row("Format", narration.format.displayName)
            row("Length", timeString(narration.durationSeconds))
            row("Size", sizeString(narration.fileSizeBytes))
            row("Source", narration.sourceName)
        }
        .studioCard()
    }

    private var actions: some View {
        VStack(spacing: 12) {
            Button {
                showShare = true
            } label: {
                Label("Share / export", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryButtonStyle())

            Button {
                newTitle = narration.title
                showRename = true
            } label: {
                Label("Rename", systemImage: "pencil").frame(maxWidth: .infinity)
            }
            .buttonStyle(SecondaryButtonStyle())

            Button(role: .destructive) {
                player.stop()
                library.deleteNarration(narration)
                dismiss()
            } label: {
                Label("Delete", systemImage: "trash").frame(maxWidth: .infinity)
            }
            .buttonStyle(SecondaryButtonStyle())
            .tint(Theme.danger)
        }
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(Theme.linenMuted)
            Spacer()
            Text(value).foregroundStyle(Theme.linen).multilineTextAlignment(.trailing)
        }
        .font(.subheadline)
    }

    private func timeString(_ t: Double) -> String {
        String(format: "%d:%02d", Int(t) / 60, Int(t) % 60)
    }
    private func sizeString(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}
