import XCTest

/// End-to-end walk through the mocked app: log in, find + add a robot, open it, clean.
final class AppFlowUITests: XCTestCase {

    private let app = XCUIApplication()

    override func setUp() {
        continueAfterFailure = false
        app.launchArguments += ["-UITesting"]
        app.launch()
    }

    private func shot(_ name: String) {
        let png = XCUIScreen.main.screenshot().pngRepresentation
        try? png.write(to: URL(fileURLWithPath: "/tmp/rr-shots/ui-\(name).png"))
    }

    func testLoginAddDeviceAndClean() {
        // Fresh install state is logged out (UserDefaults are per-install).
        let email = app.textFields["Email"]
        XCTAssertTrue(email.waitForExistence(timeout: 5))
        shot("1-login")

        // Validation error path.
        email.tap(); email.typeText("demo@ribroomba.app")
        app.secureTextFields["Password"].tap(); app.secureTextFields["Password"].typeText("wrong1")
        app.buttons["Log in"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Incorrect email or password."].waitForExistence(timeout: 5))
        shot("2-login-error")

        // Successful login.
        let password = app.secureTextFields["Password"]
        password.tap(); password.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 6) + "roomba123")
        app.buttons["Log in"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["My robots"].waitForExistence(timeout: 5))
        shot("3-devices-empty")

        // Search & add.
        app.navigationBars["My robots"].buttons["Add"].tap()
        XCTAssertTrue(app.navigationBars["Add robot"].waitForExistence(timeout: 5))
        let robot = app.staticTexts["Living Room Rib"]
        XCTAssertTrue(robot.waitForExistence(timeout: 8))
        shot("4-scanning")
        robot.tap()
        XCTAssertTrue(app.navigationBars["My robots"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["Living Room Rib"].waitForExistence(timeout: 5))
        shot("5-devices-added")

        // Open the robot -> Home.
        app.staticTexts["Living Room Rib"].tap()
        let start = app.buttons["Start cleaning"]
        XCTAssertTrue(start.waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["Connected"].waitForExistence(timeout: 5) || app.staticTexts["● Connected"].waitForExistence(timeout: 5))
        shot("6-home")
        start.tap()
        XCTAssertTrue(app.staticTexts["Cleaning"].waitForExistence(timeout: 5))
        sleep(3)
        shot("7-cleaning")

        // Other tabs.
        app.tabBars.buttons["Schedule"].tap()
        XCTAssertTrue(app.navigationBars["Schedule"].waitForExistence(timeout: 3))
        shot("8-schedule")
        app.navigationBars["Schedule"].buttons["Add"].tap()
        XCTAssertTrue(app.navigationBars["New schedule"].waitForExistence(timeout: 3))
        shot("9-editor")
        app.navigationBars["New schedule"].buttons["Cancel"].tap()
        app.tabBars.buttons["History"].tap()
        XCTAssertTrue(app.navigationBars["History"].waitForExistence(timeout: 3))
        shot("10-history")
        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 3))
        shot("11-settings")

        // Sign out returns to login.
        app.tables.staticTexts["Sign out"].tap()
        XCTAssertTrue(app.textFields["Email"].waitForExistence(timeout: 5))
        shot("12-signed-out")
    }
}
