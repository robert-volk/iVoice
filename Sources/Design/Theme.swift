import SwiftUI

/// Studio / pro-audio design system — "Emerald & Ink".
enum Theme {
    static let ink         = Color(hex: 0x14171A) // app background (near-black)
    static let inkElevated = Color(hex: 0x1C2024) // cards, sheets, panels
    static let inkLine     = Color(hex: 0x2A2F35) // hairlines, inactive strokes
    static let emerald     = Color(hex: 0x1F9D77) // primary accent / CTAs
    static let emeraldGlow = Color(hex: 0x1F9D77).opacity(0.30)
    static let linen       = Color(hex: 0xF4F2EC) // primary text
    static let linenMuted  = Color(hex: 0xF4F2EC).opacity(0.60)
    static let danger      = Color(hex: 0xE5533C)
}

extension Color {
    init(hex: UInt, alpha: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: alpha
        )
    }
}

// MARK: - Reusable style modifiers

/// Rounded card on `inkElevated` with a 1px line border and a subtle top emerald highlight.
struct StudioCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Theme.inkElevated)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Theme.inkLine, lineWidth: 1)
            )
            .overlay(alignment: .top) {
                LinearGradient(
                    colors: [Theme.emerald.opacity(0.35), .clear],
                    startPoint: .top, endPoint: .bottom
                )
                .frame(height: 2)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding(.horizontal, 1)
            }
    }
}

extension View {
    func studioCard() -> some View { modifier(StudioCard()) }
}

/// Large emerald primary button.
struct PrimaryButtonStyle: ButtonStyle {
    var enabled: Bool = true
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .foregroundStyle(Theme.ink)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(enabled ? Theme.emerald : Theme.inkLine)
            )
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.99 : 1)
    }
}

/// Secondary (outline) button.
struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .foregroundStyle(Theme.linen)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Theme.inkLine, lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}
