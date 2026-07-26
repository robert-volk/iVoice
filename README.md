# iVoice

A studio-styled iOS app that:

1. **Asks you (aloud, in a natural female voice)** to record a representative voice sample.
2. **Records** the sample with a live waveform + level meter and **plays it back to confirm**.
3. Lets you **load a document** (PDF, txt, md, rtf, or pasted text).
4. **Generates a narration** of that document and lets you **save it to a Library** as **MP3 or AAC/.m4a**.

Design: *Studio / pro-audio*, **Emerald & Ink** palette.

---

## ⚠️ Honest note about "voice cloning"

True voice cloning is **not possible fully on-device on iOS today**. iVoice has two engines behind one
`VoiceProvider` protocol, and the UI always tells you which is active:

- **On-device (default, fully private):** narration uses the best available **system voice**
  (`AVSpeechSynthesizer`). This is *your chosen voice*, **not a clone** of your recording. No network,
  no account, nothing leaves the device.
- **ElevenLabs (opt-in, real cloning):** paste an ElevenLabs API key in **Settings** to enable genuine
  cloning. Off by default. When enabled, your voice sample and document text are sent to ElevenLabs.
  The key is stored in the **Keychain**.

Your recorded sample is always captured, played back, and stored locally regardless of engine.

---

## Building from Windows (no Mac required)

This repo is built the same way as the developer's other iOS apps: **XcodeGen + GitHub Actions →
unsigned IPA → AltStore sideload**.

1. Push this repo to GitHub.
2. The workflow at `.github/workflows/ios-build.yml` runs on a macOS runner: it installs XcodeGen,
   generates `iVoice.xcodeproj`, builds an **unsigned** app, and uploads **`iVoice-unsigned.ipa`** as a
   build artifact.
3. Download the artifact from the Actions run.
4. Sideload the IPA with **AltStore** (AltServer on your PC → install the `.ipa` to your device).

You can also trigger a build manually via the **Run workflow** button (workflow_dispatch).

---

## Audio export formats

- **AAC / .m4a** — encoded natively via AVFoundation. **Works out of the box.**
- **MP3** — iOS cannot encode MP3 natively, so it requires the **LAME** encoder (LGPL):
  - Audio produced by the **ElevenLabs** engine is already MP3, so MP3 export works there with no extra
    dependency.
  - For **on-device** narration, MP3 needs LAME linked in. Until then the MP3 option falls back to AAC
    and the UI says so. To enable it:
    1. Add a LAME Swift package (see the commented block in `project.yml`).
    2. Implement `Mp3Encoder.encode(...)` against it and set `Mp3Encoder.isAvailable = true`
       (`Sources/Audio/Mp3Encoder.swift`).

---

## Project layout

```
project.yml                     XcodeGen project definition
Resources/Info.plist            Bundle config, mic usage string, dark mode
Resources/Assets.xcassets       App icon (emerald waveform), colors
.github/workflows/ios-build.yml CI: unsigned IPA artifact
Sources/
  App/            App entry + root tab shell
  Design/         Theme (Emerald & Ink) + shared modifiers
  Components/     Waveform, level meter, record button, player, sliders
  Models/         VoiceProfile, Narration, AudioFormat, VoiceOption
  Audio/          Session, recorder, player, speech renderer, exporter, MP3
  Voice/          VoiceProvider protocol + On-device & ElevenLabs providers
  Documents/      Document text extraction (PDF/txt/rtf)
  Storage/        Settings (UserDefaults), Keychain, Library store, file paths
  Features/       Onboarding, Create wizard, Library, Settings screens
```

## Privacy summary

With **no ElevenLabs key entered**, iVoice makes **no network calls** and **no data leaves the device**.
Enabling ElevenLabs is the only path that transmits your sample and text off-device.
