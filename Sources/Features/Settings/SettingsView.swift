import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settings: AppSettings

    @State private var apiKeyField = ""
    @State private var testing = false
    @State private var testResult: String?
    @State private var testOK = false

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.ink.ignoresSafeArea()
                Form {
                    elevenLabsSection
                    defaultsSection
                    aboutSection
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Settings")
            .toolbarBackground(Theme.ink, for: .navigationBar)
        }
        .onAppear { if settings.hasElevenLabsKey { apiKeyField = "••••••••••••" } }
    }

    // MARK: ElevenLabs

    private var elevenLabsSection: some View {
        Section {
            SecureField("ElevenLabs API key", text: $apiKeyField)
                .foregroundStyle(Theme.linen)

            HStack {
                Button(settings.hasElevenLabsKey ? "Update key" : "Save key") { saveKey() }
                    .foregroundStyle(Theme.emerald)
                    .disabled(apiKeyField.isEmpty || apiKeyField.hasPrefix("•"))
                Spacer()
                if settings.hasElevenLabsKey {
                    Button("Remove", role: .destructive) { removeKey() }
                }
            }

            Button {
                testKey()
            } label: {
                HStack {
                    Text("Test key")
                    if testing { ProgressView().tint(Theme.emerald) }
                }
            }
            .foregroundStyle(Theme.emerald)
            .disabled(!settings.hasElevenLabsKey || testing)

            if let testResult {
                Text(testResult)
                    .font(.footnote)
                    .foregroundStyle(testOK ? Theme.emerald : Theme.danger)
            }
        } header: {
            Text("Real voice cloning (ElevenLabs)").foregroundStyle(Theme.linenMuted)
        } footer: {
            Text("Optional. Off by default. When enabled, iVoice sends your voice sample and document text to ElevenLabs to produce a real cloned narration. The key is stored in your device Keychain.")
                .foregroundStyle(Theme.linenMuted)
        }
        .listRowBackground(Theme.inkElevated)
    }

    // MARK: Defaults

    private var defaultsSection: some View {
        Section {
            Picker("Default engine", selection: engineBinding) {
                Text("On-device").tag(NarrationEngine.onDevice)
                Text("ElevenLabs").tag(NarrationEngine.elevenLabs)
            }
            .disabled(!settings.hasElevenLabsKey)

            Picker("Default format", selection: $settings.defaultFormat) {
                Text("AAC (.m4a)").tag(AudioFormat.aac)
                Text("MP3").tag(AudioFormat.mp3)
            }
        } header: {
            Text("Defaults").foregroundStyle(Theme.linenMuted)
        }
        .foregroundStyle(Theme.linen)
        .listRowBackground(Theme.inkElevated)
    }

    private var engineBinding: Binding<NarrationEngine> {
        Binding(
            get: { settings.hasElevenLabsKey ? settings.defaultEngine : .onDevice },
            set: { settings.defaultEngine = $0 }
        )
    }

    // MARK: About

    private var aboutSection: some View {
        Section {
            HStack {
                Text("Version").foregroundStyle(Theme.linen)
                Spacer()
                Text("1.0").foregroundStyle(Theme.linenMuted)
            }
            Text("On-device narration uses a system voice and never leaves your device. It is not a clone of your recording.")
                .font(.footnote).foregroundStyle(Theme.linenMuted)
        } header: {
            Text("About").foregroundStyle(Theme.linenMuted)
        }
        .listRowBackground(Theme.inkElevated)
    }

    // MARK: Actions

    private func saveKey() {
        settings.setAPIKey(apiKeyField)
        apiKeyField = "••••••••••••"
        testResult = nil
    }

    private func removeKey() {
        settings.clearAPIKey()
        apiKeyField = ""
        testResult = nil
    }

    private func testKey() {
        guard let key = settings.apiKey else { return }
        testing = true
        testResult = nil
        Task {
            let ok = await ElevenLabsVoiceProvider.validate(apiKey: key)
            testing = false
            testOK = ok
            testResult = ok ? "Key works — cloning is available." : "Key didn't validate. Check it and try again."
        }
    }
}
