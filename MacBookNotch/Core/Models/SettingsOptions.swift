import Foundation

/// How the notch opens from its collapsed state.
nonisolated enum ExpansionTrigger: String, CaseIterable, Identifiable, Sendable {
    case hover
    case click

    var id: Self { self }

    var title: String {
        switch self {
        case .hover: "Hover"
        case .click: "Click"
        }
    }
}

/// Which display shows the notch panel.
nonisolated enum DisplayPreference: String, CaseIterable, Identifiable, Sendable {
    /// The built-in display with a notch, falling back to the primary display when the lid is closed.
    case builtIn
    /// The display that currently shows the menu bar.
    case primary

    var id: Self { self }

    var title: String {
        switch self {
        case .builtIn: "Built-in display"
        case .primary: "Primary display"
        }
    }
}
