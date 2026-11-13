import AppKit
import UserNotifications

/// Plays the sound and posts the notification for a finished timer, depending on settings.
final class TimerAlerts {
    private let settings: AppSettings

    init(settings: AppSettings) {
        self.settings = settings
    }

    func timerFinished(_ timer: CountdownTimer) {
        if settings.timerSound {
            NSSound(named: "Glass")?.play()
        }
        if settings.timerNotifications {
            let content = UNMutableNotificationContent()
            content.title = "Timer finished"
            content.body = timer.displayLabel
            if !settings.timerSound {
                content.sound = .default
            }
            let request = UNNotificationRequest(identifier: timer.id.uuidString, content: content, trigger: nil)
            UNUserNotificationCenter.current().add(request)
        }
    }

    /// Asks for permission to post notifications.
    /// - Returns: Whether notifications are allowed.
    func requestNotificationPermission() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
    }
}
