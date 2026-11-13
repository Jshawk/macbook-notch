import Foundation

/// Something short-lived or ongoing that the notch shows in its compact state.
nonisolated enum NotchActivity: Equatable, Sendable {
    case timerFinished(label: String)
    case powerChanged(isPluggedIn: Bool, level: Double)
    case trackChanged(NowPlaying)
    case meetingSoon(CalendarEvent)
    case timer(CountdownTimer)
    case nowPlaying(NowPlaying)

    nonisolated enum Kind: Equatable, Sendable {
        case timerFinished
        case powerChanged
        case trackChanged
        case meetingSoon
        case timer
        case nowPlaying
    }

    var kind: Kind {
        switch self {
        case .timerFinished: .timerFinished
        case .powerChanged: .powerChanged
        case .trackChanged: .trackChanged
        case .meetingSoon: .meetingSoon
        case .timer: .timer
        case .nowPlaying: .nowPlaying
        }
    }

    /// Higher values win when several activities want the compact notch at once.
    var priority: Int {
        switch self {
        case .timerFinished: 4
        case .powerChanged, .trackChanged: 3
        case .meetingSoon: 2
        case .timer: 1
        case .nowPlaying: 0
        }
    }

    /// How long a one-off alert stays visible. Ongoing activities have no duration.
    var displayDuration: Duration? {
        switch self {
        case .timerFinished: .seconds(10)
        case .powerChanged, .trackChanged: .seconds(4)
        case .meetingSoon, .timer, .nowPlaying: nil
        }
    }

    /// Whether VoiceOver announces the activity when it appears. Ongoing music and timers would be too chatty.
    var isAnnounced: Bool {
        switch self {
        case .timerFinished, .powerChanged, .meetingSoon: true
        case .trackChanged, .timer, .nowPlaying: false
        }
    }

    /// Returns a power alert when the Mac was plugged in or unplugged between two readings.
    static func powerChange(from old: BatteryStatus?, to new: BatteryStatus?) -> NotchActivity? {
        guard let old, let new, old.isPluggedIn != new.isPluggedIn else { return nil }
        return .powerChanged(isPluggedIn: new.isPluggedIn, level: new.level)
    }

    /// Chooses the activity to show: the highest priority wins, and among equals the most recent alert wins.
    ///
    /// - Parameters:
    ///   - alerts: One-off alerts, oldest first.
    ///   - ongoing: An ongoing activity, such as the next timer to finish or the song that's playing.
    static func resolve(alerts: [NotchActivity], ongoing: NotchActivity?) -> NotchActivity? {
        var best = ongoing
        for alert in alerts where alert.priority >= (best?.priority ?? .min) {
            best = alert
        }
        return best
    }
}
