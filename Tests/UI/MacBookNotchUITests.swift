import XCTest

@MainActor
final class MacBookNotchUITests: XCTestCase {
    private func launchApp() -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        // Arguments in this form override UserDefaults for this launch only.
        app.launchArguments += ["-expansionTrigger", "click", "-showMenuBarIcon", "YES"]
        app.launch()
        addTeardownBlock { @MainActor in app.terminate() }
        return app
    }

    func testLaunchesWithoutDockIcon() throws {
        let app = launchApp()

        // The app is an agent (LSUIElement), so it runs without becoming the active app.
        XCTAssertTrue(app.wait(for: .runningBackground, timeout: 5) || app.state == .runningForeground)
    }

    func testClickingNotchExpandsIt() throws {
        let app = launchApp()

        let notch = app.descendants(matching: .any)["notch"]
        XCTAssertTrue(notch.waitForExistence(timeout: 5))

        notch.click()

        XCTAssertTrue(app.buttons["notch.settings"].waitForExistence(timeout: 3))
    }
}
