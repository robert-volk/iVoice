import SwiftUI

struct LibraryView: View {
    @EnvironmentObject var library: LibraryStore
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.ink.ignoresSafeArea()
                if library.narrations.isEmpty && library.profiles.isEmpty {
                    emptyState
                } else {
                    List {
                        if !library.narrations.isEmpty {
                            Section {
                                ForEach(library.narrations) { narration in
                                    NavigationLink {
                                        NarrationDetailView(narration: narration)
                                    } label: {
                                        NarrationRow(narration: narration)
                                    }
                                    .listRowBackground(Theme.inkElevated)
                                }
                                .onDelete(perform: deleteNarrations)
                            } header: {
                                Text("Narrations").foregroundStyle(Theme.linenMuted)
                            }
                        }

                        if !library.profiles.isEmpty {
                            Section {
                                ForEach(library.profiles) { profile in
                                    VoiceProfileRow(profile: profile)
                                        .listRowBackground(Theme.inkElevated)
                                }
                                .onDelete(perform: deleteProfiles)
                            } header: {
                                Text("Voice profiles").foregroundStyle(Theme.linenMuted)
                            }
                        }
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Library")
            .toolbarBackground(Theme.ink, for: .navigationBar)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "square.stack.3d.up.slash")
                .font(.system(size: 56)).foregroundStyle(Theme.linenMuted)
            Text("No narrations yet")
                .font(.headline).foregroundStyle(Theme.linen)
            Text("Create one from the Create tab and it'll show up here.")
                .font(.subheadline).foregroundStyle(Theme.linenMuted)
                .multilineTextAlignment(.center)
        }
        .padding(40)
    }

    private func deleteNarrations(_ offsets: IndexSet) {
        offsets.map { library.narrations[$0] }.forEach(library.deleteNarration)
    }
    private func deleteProfiles(_ offsets: IndexSet) {
        offsets.map { library.profiles[$0] }.forEach(library.deleteProfile)
    }
}

struct NarrationRow: View {
    let narration: Narration

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "waveform")
                .foregroundStyle(Theme.emerald)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 4) {
                Text(narration.title)
                    .font(.body).foregroundStyle(Theme.linen)
                    .lineLimit(1)
                Text("\(narration.engine.displayName) · \(narration.format.displayName) · \(timeString(narration.durationSeconds))")
                    .font(.caption).foregroundStyle(Theme.linenMuted)
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }

    private func timeString(_ t: Double) -> String {
        String(format: "%d:%02d", Int(t) / 60, Int(t) % 60)
    }
}

struct VoiceProfileRow: View {
    @EnvironmentObject var settings: AppSettings
    let profile: VoiceProfile

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "mic.fill").foregroundStyle(Theme.emerald).frame(width: 28)
            VStack(alignment: .leading, spacing: 4) {
                Text(profile.name).font(.body).foregroundStyle(Theme.linen)
                Text("Sample · \(Int(profile.durationSeconds))s").font(.caption).foregroundStyle(Theme.linenMuted)
            }
            Spacer()
            if settings.activeProfileID == profile.id.uuidString {
                Text("Active").font(.caption).foregroundStyle(Theme.emerald)
            } else {
                Button("Use") { settings.activeProfileID = profile.id.uuidString }
                    .font(.caption).foregroundStyle(Theme.emerald)
            }
        }
        .padding(.vertical, 4)
    }
}
