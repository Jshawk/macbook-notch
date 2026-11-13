import CoreGraphics
import Foundation
@testable import MacBookNotch

enum TestSupport {
    /// Values reported by a 14-inch MacBook Pro at its default resolution.
    static let macBookGeometry = NotchGeometry(
        screenFrame: CGRect(x: 0, y: 0, width: 1512, height: 982),
        safeAreaTopInset: 32,
        auxiliaryTopLeftWidth: 663.5,
        auxiliaryTopRightWidth: 663.5,
        menuBarHeight: 33
    )

    /// An empty defaults suite that no other test shares.
    static func makeDefaults() -> UserDefaults {
        let name = "MacBookNotchTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }
}

/// A clock tests can move forward by hand.
final class TestClock {
    var now = Date(timeIntervalSinceReferenceDate: 800_000_000)

    func advance(by interval: TimeInterval) {
        now = now.addingTimeInterval(interval)
    }
}
