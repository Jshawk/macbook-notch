import Foundation
import Observation

/// Decides which activity the compact notch shows.
///
/// One-off alerts (a finished timer, plugging in power) expire on their own. When none are showing,
/// the notch returns to the ongoing activity: an upcoming meeting, then the next timer to finish, then the song
/// that's playing.
@Observable
final class ActivityCenter {
    private struct Alert: Equatable {
        let id = UUID()
        let activity: NotchActivity
    }

    private var alerts: [Alert] = []

    @ObservationIgnored private let timers: TimerStore
    @ObservationIgnored private let music: MusicController?
    @ObservationIgnored private let calendar: CalendarService?
    @ObservationIgnored private let settings: AppSettings?
    @ObservationIgnored private var expiryTasks: [UUID: Task<Void, Never>] = [:]

    init(timers: TimerStore, music: MusicController? = nil, calendar: CalendarService? = nil, settings: AppSettings? = nil) {
        self.timers = timers
        self.music = music
        self.calendar = calendar
        self.settings = settings
    }

    var current: NotchActivity? {
        NotchActivity.resolve(alerts: alerts.map(\.activity), ongoing: ongoing)
    }

    private var ongoing: NotchActivity? {
        if let event = calendar?.reminderEvent {
            return .meetingSoon(event)
        }
        if let timer = timers.nextTimer {
            return .timer(timer)
        }
        if settings?.showMusicActivity ?? true, let track = music?.nowPlaying, track.isPlaying {
            return .nowPlaying(track)
        }
        return nil
    }

    /// Shows an alert for its default duration.
    func post(_ activity: NotchActivity) {
        post(activity, duration: activity.displayDuration)
    }

    /// Shows an alert. A newer alert of the same kind replaces the older one so repeated events don't pile up.
    /// - Parameter duration: How long the alert stays; `nil` keeps it until `dismissAlerts()`.
    func post(_ activity: NotchActivity, duration: Duration?) {
        for alert in alerts where alert.activity.kind == activity.kind {
            expiryTasks.removeValue(forKey: alert.id)?.cancel()
        }
        alerts.removeAll { $0.activity.kind == activity.kind }

        let alert = Alert(activity: activity)
        alerts.append(alert)

        if let duration {
            expiryTasks[alert.id] = Task { [weak self] in
                try? await Task.sleep(for: duration)
                guard !Task.isCancelled else { return }
                self?.remove(alert.id)
            }
        }
    }

    /// Clears one-off alerts, for example once the user opens the notch and has seen them.
    func dismissAlerts() {
        guard !alerts.isEmpty else { return }
        expiryTasks.values.forEach { $0.cancel() }
        expiryTasks.removeAll()
        alerts.removeAll()
    }

    private func remove(_ id: UUID) {
        expiryTasks.removeValue(forKey: id)
        alerts.removeAll { $0.id == id }
    }
}
