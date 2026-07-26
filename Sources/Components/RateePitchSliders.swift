import SwiftUI

/// Per-narration rate and pitch controls (emerald-tinted).
struct RatePitchSliders: View {
    @Binding var rate: Double   // 0.0...1.0 (AVSpeechUtterance scale)
    @Binding var pitch: Double  // 0.5...2.0

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            sliderRow(
                title: "Rate",
                value: $rate,
                range: 0.30...0.70,
                readout: String(format: "%.2f", rate)
            )
            sliderRow(
                title: "Pitch",
                value: $pitch,
                range: 0.70...1.40,
                readout: String(format: "%.2f", pitch)
            )
        }
    }

    private func sliderRow(title: String, value: Binding<Double>, range: ClosedRange<Double>, readout: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title).font(.subheadline).foregroundStyle(Theme.linen)
                Spacer()
                Text(readout)
                    .font(.footnote.monospaced())
                    .foregroundStyle(Theme.linenMuted)
            }
            Slider(value: value, in: range)
                .tint(Theme.emerald)
        }
    }
}
