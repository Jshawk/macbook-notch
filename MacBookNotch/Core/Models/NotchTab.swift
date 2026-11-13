import Foundation

/// A page of the expanded notch.
nonisolated enum NotchTab: String, CaseIterable, Codable, Identifiable, Sendable {
    case home
    case calendar
    case music
    case timers
    case shelf

    var id: Self { self }

    var title: String {
        switch self {
        case .home: "Home"
        case .calendar: "Calendar"
        case .music: "Music"
        case .timers: "Timers"
        case .shelf: "Shelf"
        }
    }

    var systemImage: String {
        switch self {
        case .home: "house"
        case .calendar: "calendar"
        case .music: "music.note"
        case .timers: "timer"
        case .shelf: "tray"
        }
    }

    /// Returns every tab exactly once: stored order first, then any tabs the stored order is missing.
    static func normalizedOrder(_ stored: [String]) -> [NotchTab] {
        var seen = Set<NotchTab>()
        var order = stored.compactMap(NotchTab.init(rawValue:)).filter { seen.insert($0).inserted }
        order += allCases.filter { !seen.contains($0) }
        return order
    }
}
