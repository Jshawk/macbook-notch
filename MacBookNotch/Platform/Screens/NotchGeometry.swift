import CoreGraphics

/// Where the hardware notch, or a stand-in for it, sits on a screen.
///
/// All rects use AppKit global screen coordinates (origin at the bottom-left of the primary display).
nonisolated struct NotchGeometry: Equatable, Sendable {
    /// Size used to draw a virtual notch on displays that don't have one.
    static let fallbackNotchSize = CGSize(width: 190, height: 32)

    var screenFrame: CGRect
    var notchRect: CGRect
    var hasHardwareNotch: Bool

    /// Calculates the notch rect for a screen.
    ///
    /// - Parameters:
    ///   - screenFrame: The screen's full frame.
    ///   - safeAreaTopInset: `NSScreen.safeAreaInsets.top`; non-zero only on displays with a camera housing.
    ///   - auxiliaryTopLeftWidth: Width of `NSScreen.auxiliaryTopLeftArea`, the usable space left of the notch.
    ///   - auxiliaryTopRightWidth: Width of `NSScreen.auxiliaryTopRightArea`, the usable space right of the notch.
    ///   - menuBarHeight: Height of the menu bar, used to size the virtual notch on other displays.
    init(
        screenFrame: CGRect,
        safeAreaTopInset: CGFloat,
        auxiliaryTopLeftWidth: CGFloat?,
        auxiliaryTopRightWidth: CGFloat?,
        menuBarHeight: CGFloat
    ) {
        self.screenFrame = screenFrame

        if safeAreaTopInset > 0,
           let leftWidth = auxiliaryTopLeftWidth,
           let rightWidth = auxiliaryTopRightWidth,
           leftWidth + rightWidth < screenFrame.width {
            hasHardwareNotch = true
            notchRect = CGRect(
                x: screenFrame.minX + leftWidth,
                y: screenFrame.maxY - safeAreaTopInset,
                width: screenFrame.width - leftWidth - rightWidth,
                height: safeAreaTopInset
            )
        } else {
            let size = Self.fallbackNotchSize
            let height = menuBarHeight > 0 ? menuBarHeight : size.height
            hasHardwareNotch = false
            notchRect = CGRect(
                x: screenFrame.midX - size.width / 2,
                y: screenFrame.maxY - height,
                width: size.width,
                height: height
            )
        }
    }
}
