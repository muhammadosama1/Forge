import XCTest

final class SmokeUITests: XCTestCase {
    @MainActor
    func testCustomizedFormAndListThroughHostUI() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launch()

        let name = app.textFields["team-display-name"]
        XCTAssertTrue(name.waitForExistence(timeout: 10))
        name.tap()
        name.typeText("Edited name")

        let note = app.textFields["team-note"]
        note.tap()
        note.typeText("Edited note")
        app.buttons["Submit"].tap()
        XCTAssertTrue(app.staticTexts["Submitted"].waitForExistence(timeout: 10))

        app.terminate()
        app.launchArguments = ["--show-directory"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Host offline"].waitForExistence(timeout: 10))
        app.buttons["Reload"].tap()
        XCTAssertTrue(app.staticTexts["Host profile"].waitForExistence(timeout: 10))
    }
}
