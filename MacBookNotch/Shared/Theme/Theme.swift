import SwiftUI

enum Theme {
    enum Spacing {
        static let xSmall: CGFloat = 4
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
    }

    enum Radius {
        static let card: CGFloat = 14
    }

    enum Colors {
        static let notchBackground = Color.black
        static let cardBackground = Color.white.opacity(0.08)
        static let primaryText = Color.white
        /// Muted text. Both muted levels stay readable on `cardBackground` (at least 4.5:1).
        static let secondaryText = Color.white.opacity(0.72)
        static let tertiaryText = Color.white.opacity(0.55)
        static let controlBackground = Color.white.opacity(0.12)
        static let accent = Color.orange
        static let positive = Color.green
        static let warning = Color.red
    }

    enum Motion {
        static let notch = Animation.spring(response: 0.38, dampingFraction: 0.82)
    }
}

extension Color {
    init(_ color: CalendarColor) {
        self.init(red: color.red, green: color.green, blue: color.blue)
    }
}
