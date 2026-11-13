import CoreGraphics
import Testing
@testable import MacBookNotch

struct NotchLayoutTests {
    private let layout = NotchLayout(geometry: TestSupport.macBookGeometry)

    @Test func collapsedShapeCoversNotch() {
        let notch = layout.geometry.notchRect
        let shape = layout.shapeRect(for: .collapsed)

        #expect(shape.contains(notch))
        #expect(shape.height == notch.height)
        #expect(shape.maxY == layout.geometry.screenFrame.maxY)
        #expect(shape.midX == notch.midX)
    }

    @Test func compactShapeWidensBesideNotchWithoutGrowingTaller() {
        let notch = layout.geometry.notchRect
        let compact = layout.shapeRect(for: .compact)

        #expect(compact.height == notch.height)
        #expect(compact.midX == notch.midX)
        #expect(notch.minX - compact.minX >= NotchLayout.compactSideWidth)
        #expect(compact.width < layout.shapeRect(for: .expanded).width)
    }

    @Test func expandedShapeLeavesRoomBesideNotch() {
        let notch = layout.geometry.notchRect
        let shape = layout.shapeRect(for: .expanded)

        #expect(shape.width >= NotchLayout.minimumExpandedWidth)
        #expect(notch.minX - shape.minX >= NotchLayout.minimumSideWidth)
        #expect(shape.maxX - notch.maxX >= NotchLayout.minimumSideWidth)
        #expect(shape.height == notch.height + NotchLayout.expandedContentHeight)
        #expect(shape.maxY == layout.geometry.screenFrame.maxY)
    }

    @Test func compactExpandedShapeIsShorterInsideTheSamePanel() {
        var compact = layout
        compact.isCompact = true
        let shape = compact.shapeRect(for: .expanded)

        #expect(shape.height == layout.geometry.notchRect.height + NotchLayout.compactExpandedContentHeight)
        #expect(shape.width == layout.shapeRect(for: .expanded).width)
        #expect(shape.maxY == layout.geometry.screenFrame.maxY)
        #expect(compact.panelFrame == layout.panelFrame, "The window doesn't resize")
        #expect(compact.panelFrame.contains(shape))
        #expect(!compact.interactiveRect(for: .expanded).contains(
            CGPoint(x: shape.midX, y: layout.shapeRect(for: .expanded).minY + 1)
        ), "The space below the shorter notch passes clicks through")
    }

    @Test func expandedShapeStaysOnNarrowScreens() {
        let narrow = NotchGeometry(
            screenFrame: CGRect(x: 0, y: 0, width: 600, height: 400),
            safeAreaTopInset: 0,
            auxiliaryTopLeftWidth: nil,
            auxiliaryTopRightWidth: nil,
            menuBarHeight: 24
        )
        let layout = NotchLayout(geometry: narrow)

        #expect(layout.panelFrame.width <= narrow.screenFrame.width)
        #expect(layout.panelFrame.minX >= narrow.screenFrame.minX)
    }

    @Test func panelContainsEveryPresentationAndSitsAtTopOfScreen() {
        let panel = layout.panelFrame

        for presentation in [NotchPresentation.collapsed, .compact, .banner, .expanded] {
            #expect(panel.contains(layout.shapeRect(for: presentation)))
        }
        #expect(panel.maxY == layout.geometry.screenFrame.maxY)
        #expect(panel.midX == layout.geometry.notchRect.midX)
    }

    @Test func expandedAreaContainsSmallerHoverAreas() {
        let expanded = layout.interactiveRect(for: .expanded)

        // Otherwise the notch could open from a point that immediately counts as outside it, and flicker.
        for presentation in [NotchPresentation.collapsed, .compact, .banner] {
            #expect(expanded.contains(layout.interactiveRect(for: presentation)))
        }
    }

    @Test func bannerAddsALineBelowTheCompactNotch() {
        let compact = layout.shapeRect(for: .compact)
        let banner = layout.shapeRect(for: .banner)

        #expect(banner.width == compact.width)
        #expect(banner.height == compact.height + NotchLayout.bannerLineHeight)
        #expect(banner.maxY == compact.maxY)
    }

    @Test func expandedAreaIncludesTopEdgeAcrossItsWidth() {
        let shape = layout.shapeRect(for: .expanded)
        let expanded = layout.interactiveRect(for: .expanded)

        for x in [shape.minX + 1, shape.midX, shape.maxX - 1] {
            #expect(expanded.contains(CGPoint(x: x, y: layout.geometry.screenFrame.maxY)))
        }
    }

    @Test func collapsedHoverAreaExtendsPastShape() {
        let shape = layout.shapeRect(for: .collapsed)
        let hoverArea = layout.interactiveRect(for: .collapsed)

        #expect(hoverArea.contains(shape))
        // The pointer can rest on the top row of pixels, which CGRect treats as outside the shape.
        #expect(hoverArea.contains(CGPoint(x: shape.midX, y: shape.maxY)))
    }
}
