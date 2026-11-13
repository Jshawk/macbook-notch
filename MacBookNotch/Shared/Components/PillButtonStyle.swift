import SwiftUI

/// A small capsule button, so actions placed side by side read as separate buttons.
struct PillButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .lineLimit(1)
            .foregroundStyle(Theme.Colors.accent)
            .padding(.horizontal, Theme.Spacing.medium)
            .frame(height: 24)
            .background(
                configuration.isPressed ? Theme.Colors.cardBackground : Theme.Colors.controlBackground,
                in: Capsule()
            )
            .contentShape(Capsule())
            .opacity(isEnabled ? 1 : 0.5)
    }
}
