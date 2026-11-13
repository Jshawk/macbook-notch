import Foundation
import Testing
@testable import MacBookNotch

@MainActor
struct ActivityCenterTests {
    private let timers = TimerStore(defaults: TestSupport.makeDefaults())

    @Test func showsRunningTimerWhenNoAlerts() {
        let center = ActivityCenter(timers: timers)
        #expect(center.current == nil)

        let timer = timers.start(duration: 60)

        #expect(center.current == .timer(timer))
    }

    @Test func newerAlertOfSameKindReplacesOlder() {
        let center = ActivityCenter(timers: timers)

        center.post(.powerChanged(isPluggedIn: true, level: 0.5), duration: nil)
        center.post(.powerChanged(isPluggedIn: false, level: 0.5), duration: nil)
        center.dismissAlerts()

        #expect(center.current == nil, "Replaced alerts shouldn't linger after dismissal")
    }

    @Test func returnsToTimerAfterAlertExpires() async throws {
        let center = ActivityCenter(timers: timers)
        let timer = timers.start(duration: 600)

        center.post(.powerChanged(isPluggedIn: true, level: 0.5), duration: .milliseconds(50))
        #expect(center.current?.kind == .powerChanged)

        try await Task.sleep(for: .milliseconds(300))
        #expect(center.current == .timer(timer))
    }

    @Test func dismissingAlertsKeepsOngoingActivity() {
        let center = ActivityCenter(timers: timers)
        let timer = timers.start(duration: 600)
        center.post(.timerFinished(label: "Tea"), duration: nil)

        center.dismissAlerts()

        #expect(center.current == .timer(timer))
    }
}
