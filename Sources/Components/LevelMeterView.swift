import SwiftUI

/// Thin horizontal dB meter. Turns amber near clipping, danger when hot.
struct LevelMeterView: View {
    var level: CGFloat // normalized 0...1

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.inkLine)
                Capsule()
                    .fill(color)
                    .frame(width: max(2, geo.size.width * min(1, max(0, level))))
            }
        }
        .frame(height: 6)
        .animation(.easeOut(duration: 0.08), value: level)
    }

    private var color: Color {
        switch level {
        case ..<0.75: return Theme.emerald
        case ..<0.92: return Color(hex: 0xE8A13A) // amber warning
        default:      return Theme.danger
        }
    }
}
