import SwiftUI

/// Emerald amplitude bars on ink, with a soft glow. Drives both live recording
/// (levels appended over time) and static previews.
struct WaveformView: View {
    var levels: [CGFloat]          // normalized 0...1
    var active: Bool = true
    var barCount: Int = 48

    var body: some View {
        GeometryReader { geo in
            let count = barCount
            let spacing: CGFloat = 3
            let barWidth = max(2, (geo.size.width - spacing * CGFloat(count - 1)) / CGFloat(count))
            let display = normalized(count: count)

            HStack(alignment: .center, spacing: spacing) {
                ForEach(0..<count, id: \.self) { i in
                    Capsule()
                        .fill(active ? Theme.emerald : Theme.linenMuted)
                        .frame(
                            width: barWidth,
                            height: max(3, display[i] * geo.size.height)
                        )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .shadow(color: active ? Theme.emeraldGlow : .clear, radius: 8)
            .animation(.easeOut(duration: 0.08), value: display)
        }
    }

    /// Map the incoming levels onto exactly `count` bars (take the most recent).
    private func normalized(count: Int) -> [CGFloat] {
        guard !levels.isEmpty else { return Array(repeating: 0.04, count: count) }
        if levels.count >= count {
            return Array(levels.suffix(count))
        }
        return Array(repeating: 0.04, count: count - levels.count) + levels
    }
}
