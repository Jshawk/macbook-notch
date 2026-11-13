import Foundation
import Testing
@testable import MacBookNotch

struct NotchActivityTests {
    private let timer = CountdownTimer(label: "Tea", duration: 300, startedAt: .now)

    @Test func alertsOutrankOngoingTimer() {
        let power = NotchActivity.powerChanged(isPluggedIn: true, level: 0.5)

        #expect(NotchActivity.resolve(alerts: [power], ongoing: .timer(timer)) == power)
    }

    @Test func finishedTimerOutranksPowerChange() {
        let finished = NotchActivity.timerFinished(label: "Tea")
        let power = NotchActivity.powerChanged(isPluggedIn: false, level: 0.5)

        #expect(NotchActivity.resolve(alerts: [finished, power], ongoing: nil) == finished)
    }

    @Test func newestAlertWinsAmongEqualPriority() {
        let first = NotchActivity.powerChanged(isPluggedIn: true, level: 0.5)
        let second = NotchActivity.powerChanged(isPluggedIn: false, level: 0.5)

        #expect(NotchActivity.resolve(alerts: [first, second], ongoing: nil) == second)
    }

    @Test func fallsBackToOngoingActivity() {
        #expect(NotchActivity.resolve(alerts: [], ongoing: .timer(timer)) == .timer(timer))
        #expect(NotchActivity.resolve(alerts: [], ongoing: nil) == nil)
    }

    @Test func detectsPluggingInAndUnplugging() {
        let onBattery = BatteryStatus(level: 0.4, isCharging: false, isPluggedIn: false)
        let pluggedIn = BatteryStatus(level: 0.4, isCharging: true, isPluggedIn: true)

        #expect(NotchActivity.powerChange(from: onBattery, to: pluggedIn) == .powerChanged(isPluggedIn: true, level: 0.4))
        #expect(NotchActivity.powerChange(from: pluggedIn, to: onBattery) == .powerChanged(isPluggedIn: false, level: 0.4))
    }

    @Test func ignoresLevelChangesAndFirstReading() {
        let before = BatteryStatus(level: 0.4, isCharging: false, isPluggedIn: false)
        let after = BatteryStatus(level: 0.39, isCharging: false, isPluggedIn: false)

        #expect(NotchActivity.powerChange(from: before, to: after) == nil)
        #expect(NotchActivity.powerChange(from: nil, to: after) == nil)
    }
}
