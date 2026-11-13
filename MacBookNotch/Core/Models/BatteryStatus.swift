import Foundation
import IOKit.ps

nonisolated struct BatteryStatus: Equatable, Sendable {
    /// Charge level from 0 to 1.
    var level: Double
    var isCharging: Bool
    var isPluggedIn: Bool

    var percentage: Int {
        Int((level * 100).rounded())
    }

    /// Reads a power source description returned by `IOPSGetPowerSourceDescription`.
    /// Returns `nil` for anything other than an internal battery.
    init?(powerSourceDescription description: [String: Any]) {
        guard description[kIOPSTypeKey] as? String == kIOPSInternalBatteryType,
              let currentCapacity = description[kIOPSCurrentCapacityKey] as? Int,
              let maxCapacity = description[kIOPSMaxCapacityKey] as? Int,
              maxCapacity > 0
        else { return nil }

        level = min(max(Double(currentCapacity) / Double(maxCapacity), 0), 1)
        isCharging = description[kIOPSIsChargingKey] as? Bool ?? false
        isPluggedIn = description[kIOPSPowerSourceStateKey] as? String == kIOPSACPowerValue
    }

    init(level: Double, isCharging: Bool, isPluggedIn: Bool) {
        self.level = level
        self.isCharging = isCharging
        self.isPluggedIn = isPluggedIn
    }
}
