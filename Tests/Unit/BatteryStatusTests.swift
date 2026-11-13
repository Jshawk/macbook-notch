import Testing
@testable import MacBookNotch

struct BatteryStatusTests {
    private func description(
        type: String = "InternalBattery",
        current: Int = 80,
        max: Int = 100,
        charging: Bool = false,
        state: String = "Battery Power"
    ) -> [String: Any] {
        [
            "Type": type,
            "Current Capacity": current,
            "Max Capacity": max,
            "Is Charging": charging,
            "Power Source State": state,
        ]
    }

    @Test func readsInternalBattery() throws {
        let status = try #require(BatteryStatus(powerSourceDescription: description()))

        #expect(status.level == 0.8)
        #expect(status.percentage == 80)
        #expect(!status.isCharging)
        #expect(!status.isPluggedIn)
    }

    @Test func readsChargingOnACPower() throws {
        let status = try #require(BatteryStatus(powerSourceDescription: description(
            charging: true,
            state: "AC Power"
        )))

        #expect(status.isCharging)
        #expect(status.isPluggedIn)
    }

    @Test func ignoresOtherPowerSources() {
        #expect(BatteryStatus(powerSourceDescription: description(type: "UPS")) == nil)
    }

    @Test func rejectsMissingCapacity() {
        #expect(BatteryStatus(powerSourceDescription: description(max: 0)) == nil)
        #expect(BatteryStatus(powerSourceDescription: ["Type": "InternalBattery"]) == nil)
    }

    @Test func clampsLevel() throws {
        let status = try #require(BatteryStatus(powerSourceDescription: description(current: 120)))

        #expect(status.level == 1)
    }
}
