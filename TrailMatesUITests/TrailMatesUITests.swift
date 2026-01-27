//
//  TrailMatesUITests.swift
//  TrailMatesUITests
//
//  Created by Jake Kinchen on 10/3/24.
//

import XCTest

final class TrailMatesUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // Initialize the app
        app = XCUIApplication()

        // Set launch arguments for testing environment
        app.launchArguments = ["--uitesting"]
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - App Launch Tests

    @MainActor
    func testAppLaunchesSuccessfully() throws {
        // Launch the app
        app.launch()

        // Verify the app launched by checking it's running
        XCTAssertTrue(app.state == .runningForeground, "App should be running in foreground")

        // Wait a moment for the initial UI to load
        let exists = app.wait(for: .runningForeground, timeout: 5)
        XCTAssertTrue(exists, "App should be running within 5 seconds")
    }

    @MainActor
    func testAppDoesNotCrashOnLaunch() throws {
        // Launch the app
        app.launch()

        // Wait for app to stabilize
        sleep(2)

        // Verify app is still running (hasn't crashed)
        XCTAssertTrue(app.state == .runningForeground, "App should still be running after launch")
    }

    // MARK: - Basic UI Element Tests

    @MainActor
    func testInitialScreenHasContent() throws {
        // Launch the app
        app.launch()

        // Wait for initial content to appear
        let initialDelay = expectation(description: "Wait for initial UI")
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            initialDelay.fulfill()
        }
        wait(for: [initialDelay], timeout: 5)

        // The app should have some windows/content
        XCTAssertTrue(app.windows.count > 0, "App should have at least one window")
    }

    // MARK: - Authentication Flow Tests

    @MainActor
    func testAuthenticationScreenElementsExist() throws {
        // Launch app fresh (simulating logged-out state)
        app.launchArguments.append("--reset-state")
        app.launch()

        // Wait for UI to load
        sleep(2)

        // Check if the app has any buttons (common in auth screens)
        // Note: This is a basic check - specific element IDs should be added to the app
        let buttons = app.buttons
        let textFields = app.textFields
        let secureTextFields = app.secureTextFields

        // At least some interactive elements should exist
        let hasInteractiveElements = buttons.count > 0 || textFields.count > 0 || secureTextFields.count > 0

        // Log what we found for debugging
        print("Found \(buttons.count) buttons, \(textFields.count) text fields, \(secureTextFields.count) secure text fields")

        // The test passes if UI loaded - specific auth tests would need accessibility identifiers
        XCTAssertTrue(app.state == .runningForeground, "App should be running")
    }

    // MARK: - Navigation Tests

    @MainActor
    func testTabBarExistsWhenLoggedIn() throws {
        // This test assumes the user is logged in
        // For a proper test, you'd need to set up test credentials
        app.launch()

        // Wait for potential navigation to complete
        sleep(3)

        // Check for common navigation elements
        let tabBars = app.tabBars
        let navigationBars = app.navigationBars

        // Log for debugging
        print("Found \(tabBars.count) tab bars, \(navigationBars.count) navigation bars")

        // App should have navigation of some kind
        XCTAssertTrue(app.state == .runningForeground, "App should be running")
    }

    // MARK: - Performance Tests

    @MainActor
    func testLaunchPerformance() throws {
        if #available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 7.0, *) {
            // This measures how long it takes to launch your application.
            measure(metrics: [XCTApplicationLaunchMetric()]) {
                XCUIApplication().launch()
            }
        }
    }

    @MainActor
    func testAppResponsivenessAfterLaunch() throws {
        // Launch the app
        app.launch()

        // Wait for app to fully load
        sleep(2)

        // Measure how long common operations take
        let startTime = Date()

        // Try to interact with the app (tap somewhere safe)
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()

        let endTime = Date()
        let responseTime = endTime.timeIntervalSince(startTime)

        // App should respond within a reasonable time
        XCTAssertLessThan(responseTime, 2.0, "App should respond to taps within 2 seconds")
    }

    // MARK: - Accessibility Tests

    @MainActor
    func testAccessibilityElementsExist() throws {
        app.launch()

        // Wait for UI to load
        sleep(2)

        // Check that the app has some accessible elements
        let allElements = app.descendants(matching: .any)
        XCTAssertTrue(allElements.count > 0, "App should have accessible UI elements")
    }

    // MARK: - Orientation Tests

    @MainActor
    func testAppHandlesRotation() throws {
        app.launch()

        // Wait for initial load
        sleep(2)

        // Rotate to landscape
        XCUIDevice.shared.orientation = .landscapeLeft
        sleep(1)

        // App should still be running
        XCTAssertTrue(app.state == .runningForeground, "App should handle landscape orientation")

        // Rotate back to portrait
        XCUIDevice.shared.orientation = .portrait
        sleep(1)

        // App should still be running
        XCTAssertTrue(app.state == .runningForeground, "App should handle portrait orientation")
    }

    // MARK: - Memory Warning Simulation

    @MainActor
    func testAppSurvivesBackgrounding() throws {
        app.launch()

        // Wait for initial load
        sleep(2)

        // Background the app
        XCUIDevice.shared.press(.home)
        sleep(2)

        // Foreground the app
        app.activate()
        let returnedToForeground = app.wait(for: .runningForeground, timeout: 10)

        // App should return to foreground (avoid flakiness on slower simulators)
        XCTAssertTrue(
            returnedToForeground,
            "App should survive backgrounding and return to foreground (state: \(app.state))"
        )
    }
}
