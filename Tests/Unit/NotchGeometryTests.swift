import CoreGraphics
import Testing
@testable import MacBookNotch

struct NotchGeometryTests {
    /// Values reported by a 14-inch MacBook Pro at its default resolution.
    private let macBookScreen = TestSupport.macBookGeometry.screenFrame

    @Test func detectsHardwareNotchFromAuxiliaryAreas() {
        let geometry = NotchGeometry(
            screenFrame: macBookScreen,
            safeAreaTopInset: 32,
            auxiliaryTopLeftWidth: 663.5,
            auxiliaryTopRightWidth: 663.5,
            menuBarHeight: 33
        )

        #expect(geometry.hasHardwareNotch)
        #expect(geometry.notchRect == CGRect(x: 663.5, y: 950, width: 185, height: 32))
    }

    @Test func offsetsNotchForScreensAwayFromOrigin() {
        let screen = macBookScreen.offsetBy(dx: -1512, dy: 200)
        let geometry = NotchGeometry(
            screenFrame: screen,
            safeAreaTopInset: 32,
            auxiliaryTopLeftWidth: 663.5,
            auxiliaryTopRightWidth: 663.5,
            menuBarHeight: 33
        )

        #expect(geometry.notchRect == CGRect(x: -848.5, y: 1150, width: 185, height: 32))
    }

    @Test func usesCenteredVirtualNotchWithoutSafeAreaInset() {
        let screen = CGRect(x: 0, y: 0, width: 2560, height: 1440)
        let geometry = NotchGeometry(
            screenFrame: screen,
            safeAreaTopInset: 0,
            auxiliaryTopLeftWidth: nil,
            auxiliaryTopRightWidth: nil,
            menuBarHeight: 25
        )

        #expect(!geometry.hasHardwareNotch)
        #expect(geometry.notchRect.midX == screen.midX)
        #expect(geometry.notchRect.maxY == screen.maxY)
        #expect(geometry.notchRect.height == 25)
        #expect(geometry.notchRect.width == NotchGeometry.fallbackNotchSize.width)
    }

    @Test func fallsBackWhenMenuBarIsHidden() {
        let geometry = NotchGeometry(
            screenFrame: CGRect(x: 0, y: 0, width: 1920, height: 1080),
            safeAreaTopInset: 0,
            auxiliaryTopLeftWidth: nil,
            auxiliaryTopRightWidth: nil,
            menuBarHeight: 0
        )

        #expect(geometry.notchRect.height == NotchGeometry.fallbackNotchSize.height)
    }

    @Test func ignoresInconsistentAuxiliaryAreas() {
        let geometry = NotchGeometry(
            screenFrame: macBookScreen,
            safeAreaTopInset: 32,
            auxiliaryTopLeftWidth: 1000,
            auxiliaryTopRightWidth: 1000,
            menuBarHeight: 33
        )

        #expect(!geometry.hasHardwareNotch)
    }
}
