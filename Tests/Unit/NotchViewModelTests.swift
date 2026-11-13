import CoreGraphics
import Foundation
import Testing
@testable import MacBookNotch

@MainActor
struct NotchViewModelTests {
    private let geometry = TestSupport.macBookGeometry
    private let defaults = TestSupport.makeDefaults()
    private let settings: AppSettings
    private let timers: TimerStore
    private let activities: ActivityCenter

    private var notchCenter: CGPoint {
        CGPoint(x: geometry.notchRect.midX, y: geometry.notchRect.midY)
    }
    private let farAway = CGPoint(x: 10, y: 10)

    init() {
        settings = AppSettings(defaults: defaults)
        settings.hoverDelay = 0
        timers = TimerStore(defaults: defaults)
        activities = ActivityCenter(timers: timers)
    }

    private func makeModel() -> NotchViewModel {
        NotchViewModel(geometry: geometry, settings: settings, activities: activities, collapseDelay: 0)
    }

    @Test func layoutIsCompactWhileVisibleTabShowsAMessage() {
        let model = makeModel()
        model.showsMessage = { $0 == .music }

        model.select(.home)
        #expect(!model.layout.isCompact)
        model.select(.music)
        #expect(model.layout.isCompact)
    }

    @Test func startsCollapsed() {
        let model = makeModel()

        #expect(model.state == .collapsed)
        #expect(model.presentation == .collapsed)
    }

    @Test func hoveringNotchExpandsIt() {
        let model = makeModel()

        let captured = model.pointerMoved(to: notchCenter)

        #expect(captured)
        #expect(model.state == .expanded)
    }

    @Test func leavingExpandedNotchCollapsesIt() {
        let model = makeModel()
        model.pointerMoved(to: notchCenter)

        let captured = model.pointerMoved(to: farAway)

        #expect(!captured)
        #expect(model.state == .collapsed)
    }

    @Test func pointerPushedAgainstTopEdgeStaysOpen() {
        let model = makeModel()
        // Pushing the cursor into the top of the screen reports the screen's top edge as its location.
        let topEdge = CGPoint(x: geometry.notchRect.midX, y: geometry.screenFrame.maxY)

        model.pointerMoved(to: topEdge)
        #expect(model.state == .expanded)

        // Further movement against the edge reports the same location.
        model.pointerMoved(to: topEdge)
        #expect(model.state == .expanded)
    }

    @Test func movingWithinExpandedAreaKeepsItOpen() {
        let model = makeModel()
        model.pointerMoved(to: notchCenter)
        let expanded = model.layout.shapeRect(for: .expanded)

        model.pointerMoved(to: CGPoint(x: expanded.minX + 5, y: expanded.minY + 5))

        #expect(model.state == .expanded)
    }

    @Test func clickTriggerIgnoresHover() {
        settings.expansionTrigger = .click
        let model = makeModel()

        let captured = model.pointerMoved(to: notchCenter)

        #expect(captured, "The notch still needs mouse events so it can be clicked")
        #expect(model.state == .collapsed)
    }

    @Test func clickingOutsideCollapses() {
        let model = makeModel()
        model.expand()

        model.mouseDown(at: farAway)

        #expect(model.state == .collapsed)
    }

    @Test func clickingInsideKeepsItOpen() {
        let model = makeModel()
        model.expand()

        model.mouseDown(at: notchCenter)

        #expect(model.state == .expanded)
    }

    @Test func toggleAlternatesState() {
        let model = makeModel()

        model.toggle()
        #expect(model.state == .expanded)
        model.toggle()
        #expect(model.state == .collapsed)
    }

    @Test func hoverDelayWaitsBeforeExpanding() async throws {
        settings.hoverDelay = 0.05
        let model = makeModel()

        model.pointerMoved(to: notchCenter)
        #expect(model.state == .collapsed)

        try await Task.sleep(for: .milliseconds(300))
        #expect(model.state == .expanded)
    }

    @Test func leavingBeforeHoverDelayCancelsExpansion() async throws {
        settings.hoverDelay = 0.1
        let model = makeModel()

        model.pointerMoved(to: notchCenter)
        model.pointerMoved(to: farAway)

        try await Task.sleep(for: .milliseconds(300))
        #expect(model.state == .collapsed)
    }

    @Test func changingScreensCollapsesAndMovesNotch() {
        let model = makeModel()
        model.expand()
        let external = NotchGeometry(
            screenFrame: CGRect(x: 1512, y: 0, width: 2560, height: 1440),
            safeAreaTopInset: 0,
            auxiliaryTopLeftWidth: nil,
            auxiliaryTopRightWidth: nil,
            menuBarHeight: 25
        )

        model.updateGeometry(external)

        #expect(model.state == .collapsed)
        #expect(model.layout.geometry == external)
    }

    // MARK: Compact activities

    @Test func activityMakesCollapsedNotchCompact() {
        let model = makeModel()

        activities.post(.powerChanged(isPluggedIn: true, level: 0.5), duration: nil)

        #expect(model.state == .collapsed)
        #expect(model.presentation == .compact)
        #expect(model.interactiveRect.width > model.layout.interactiveRect(for: .collapsed).width)
    }

    @Test func songChangeShowsBanner() {
        let model = makeModel()
        let track = NowPlaying(
            source: .music, trackID: "1", title: "Song", artist: "Artist", album: "",
            isPlaying: true, duration: 200, position: 0, positionDate: .now, artworkURL: nil
        )

        activities.post(.trackChanged(track), duration: nil)

        #expect(model.presentation == .banner)
        model.expand()
        #expect(model.visibleTab == .home, "Opening by hover keeps the current tab")
    }

    @Test func expandingDismissesAlertsButKeepsRunningTimer() {
        let model = makeModel()
        timers.start(duration: 300)
        activities.post(.timerFinished(label: "Tea"), duration: nil)

        model.expand()
        model.collapse()

        #expect(model.presentation == .compact)
        #expect(activities.current?.kind == .timer)
    }

    // MARK: Holding the notch open

    @Test func keyboardHoldIgnoresPointerLeaving() {
        let model = makeModel()
        model.pointerMoved(to: notchCenter)
        model.expand(holding: .keyboard)

        model.pointerMoved(to: farAway)

        #expect(model.state == .expanded)
    }

    @Test func clickOutsideClosesKeyboardHold() {
        let model = makeModel()
        model.expand(holding: .keyboard)

        model.mouseDown(at: farAway)

        #expect(model.state == .collapsed)
        #expect(!model.isHeldOpen)
    }

    @Test func draggingOutIgnoresClicksElsewhere() {
        let model = makeModel()
        model.expand()
        model.hold(.dragging)

        model.mouseDown(at: farAway)

        #expect(model.state == .expanded)
    }

    @Test func releasingHoldCollapsesIfPointerAlreadyLeft() {
        let model = makeModel()
        model.pointerMoved(to: notchCenter)
        model.hold(.editing)
        model.pointerMoved(to: farAway)
        #expect(model.state == .expanded)

        model.release(.editing)

        #expect(model.state == .collapsed)
    }

    @Test func releasingHoldKeepsItOpenWhilePointerInside() {
        let model = makeModel()
        model.pointerMoved(to: notchCenter)
        model.hold(.editing)

        model.release(.editing)

        #expect(model.state == .expanded)
    }

    @Test func dropTargetingOpensNotchEvenWithClickTrigger() {
        settings.expansionTrigger = .click
        let model = makeModel()

        model.setDropTargeted(true)

        #expect(model.state == .expanded)
        #expect(model.isDropTargeted)
    }

    // MARK: Tabs

    @Test func remembersSelectedTabBetweenOpenings() {
        let model = makeModel()
        model.expand()
        model.select(.timers)

        model.collapse()
        model.expand()

        #expect(model.visibleTab == .timers)
    }

    @Test func expandingCanSwitchToActivityTab() {
        let model = makeModel()

        model.expand(showing: NotchActivity.timerFinished(label: "Tea").tab)

        #expect(model.visibleTab == .timers)
    }

    @Test func hiddenTabFallsBackToFirstVisible() {
        let model = makeModel()
        model.select(.music)

        settings.setVisible(.music, false)

        #expect(model.visibleTab == .home)
        model.select(.music)
        #expect(model.visibleTab == .home, "A hidden tab can't be selected")
    }

    @Test func draggingFilesOverOpensShelf() {
        let model = makeModel()

        model.setDropTargeted(true)

        #expect(model.visibleTab == .shelf)
    }

    @Test func reportsStateChanges() {
        let model = makeModel()
        var changes: [NotchState] = []
        model.onStateChange = { changes.append($0) }

        model.expand()
        model.expand()
        model.collapse()

        #expect(changes == [.expanded, .collapsed])
    }
}
