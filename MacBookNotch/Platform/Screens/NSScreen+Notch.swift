import AppKit

extension NSScreen {
    var displayID: CGDirectDisplayID? {
        deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
    }

    var isBuiltIn: Bool {
        displayID.map { CGDisplayIsBuiltin($0) != 0 } ?? false
    }

    var hasNotch: Bool {
        safeAreaInsets.top > 0
    }

    var notchGeometry: NotchGeometry {
        NotchGeometry(
            screenFrame: frame,
            safeAreaTopInset: safeAreaInsets.top,
            auxiliaryTopLeftWidth: auxiliaryTopLeftArea?.width,
            auxiliaryTopRightWidth: auxiliaryTopRightArea?.width,
            menuBarHeight: frame.maxY - visibleFrame.maxY
        )
    }
}
