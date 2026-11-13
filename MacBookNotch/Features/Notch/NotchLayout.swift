import CoreGraphics

/// Whether the user has opened the notch.
nonisolated enum NotchState: Equatable, Sendable {
    case collapsed
    case expanded
}

/// What the notch currently draws. A collapsed notch becomes compact while an activity is showing,
/// or a banner when the activity needs a line of text, such as the name of a new song.
nonisolated enum NotchPresentation: Equatable, Sendable {
    case collapsed
    case compact
    case banner
    case expanded
}

/// Sizes and positions for the notch in each presentation, in global screen coordinates.
nonisolated struct NotchLayout: Equatable, Sendable {
    /// Space below the notch strip used by expanded content.
    static let expandedContentHeight: CGFloat = 140
    /// Space below the notch strip when the tab shows only a one-row `MessageCard`, which fits a two-line detail.
    static let compactExpandedContentHeight: CGFloat = 92
    static let minimumExpandedWidth: CGFloat = 600
    /// Minimum room on each side of the hardware notch for the tab bar and header buttons.
    static let minimumSideWidth: CGFloat = 150
    /// Room on each side of the hardware notch for compact activity content.
    static let compactSideWidth: CGFloat = 76
    /// Height of the text line a banner adds below the notch.
    static let bannerLineHeight: CGFloat = 30
    /// Horizontal inset of tab content inside the expanded shape.
    static let contentInset: CGFloat = 12

    /// Radius of the outward curves where the notch meets the top edge of the screen.
    static let collapsedTopRadius: CGFloat = 6
    static let expandedTopRadius: CGFloat = 14
    static let collapsedBottomRadius: CGFloat = 10
    static let compactBottomRadius: CGFloat = 12
    static let bannerBottomRadius: CGFloat = 18
    static let expandedBottomRadius: CGFloat = 26

    /// Extra margin around the collapsed or compact notch that still counts as hovering it.
    static let hoverPadding: CGFloat = 6
    /// Transparent margin around the expanded shape that leaves room for its shadow.
    static let shadowPadding: CGFloat = 24

    var geometry: NotchGeometry
    /// Whether the open notch uses the shorter height for a one-row message.
    var isCompact = false

    func shapeSize(for presentation: NotchPresentation) -> CGSize {
        let notch = geometry.notchRect.size

        switch presentation {
        case .collapsed:
            return CGSize(width: notch.width + 2 * Self.collapsedTopRadius, height: notch.height)
        case .compact:
            return CGSize(
                width: notch.width + 2 * (Self.collapsedTopRadius + Self.compactSideWidth),
                height: notch.height
            )
        case .banner:
            return CGSize(
                width: shapeSize(for: .compact).width,
                height: notch.height + Self.bannerLineHeight
            )
        case .expanded:
            let contentHeight = isCompact ? Self.compactExpandedContentHeight : Self.expandedContentHeight
            return CGSize(width: expandedWidth, height: notch.height + contentHeight)
        }
    }

    private var expandedWidth: CGFloat {
        let notch = geometry.notchRect.size
        var width = max(
            Self.minimumExpandedWidth,
            notch.width + 2 * (Self.expandedTopRadius + Self.minimumSideWidth)
        )
        // Keep the panel, including its shadow margin, on screen.
        let available = geometry.screenFrame.width - 2 * Self.shadowPadding
        if available > 0 {
            width = min(width, available)
        }
        return width
    }

    /// The notch shape's frame, centered on the notch and attached to the top of the screen.
    func shapeRect(for presentation: NotchPresentation) -> CGRect {
        let size = shapeSize(for: presentation)
        return CGRect(
            x: geometry.notchRect.midX - size.width / 2,
            y: geometry.screenFrame.maxY - size.height,
            width: size.width,
            height: size.height
        )
    }

    /// The area that captures the pointer. Everything else in the panel passes clicks through.
    func interactiveRect(for presentation: NotchPresentation) -> CGRect {
        switch presentation {
        case .collapsed, .compact, .banner:
            shapeRect(for: presentation).insetBy(dx: -Self.hoverPadding, dy: -Self.hoverPadding)
        case .expanded:
            // Extend past the top of the screen: a cursor pushed against the edge reports the edge itself,
            // which `CGRect.contains` treats as outside. Also cover the smaller hover areas, so a point that
            // opens the notch can never count as outside the open notch; otherwise it opens and closes in a loop.
            shapeRect(for: .expanded)
                .extendingTop(by: Self.hoverPadding)
                .union(interactiveRect(for: .collapsed))
                .union(interactiveRect(for: .compact))
                .union(interactiveRect(for: .banner))
        }
    }

    /// The panel's frame. It stays at the full expanded size, even while the notch is compact, so the shape can
    /// animate without resizing the window.
    var panelFrame: CGRect {
        let width = expandedWidth + 2 * Self.shadowPadding
        let height = geometry.notchRect.height + Self.expandedContentHeight + Self.shadowPadding
        return CGRect(
            x: geometry.notchRect.midX - width / 2,
            y: geometry.screenFrame.maxY - height,
            width: width,
            height: height
        )
    }
}

nonisolated private extension CGRect {
    /// Grows the rect upward, which is toward the top of the screen in AppKit coordinates.
    func extendingTop(by amount: CGFloat) -> CGRect {
        CGRect(x: minX, y: minY, width: width, height: height + amount)
    }
}
