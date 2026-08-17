import XCTest

final class WryticUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testAppLaunches() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.navigationBars["Wrytic"].waitForExistence(timeout: 5))
    }

    func testSidebarNavigatesToSettings() throws {
        let app = XCUIApplication()
        app.launch()

        app.descendants(matching: .any)["sidebar.Settings"].firstMatch.tap()

        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
    }

    func testNewNotebookButtonAddsNotebook() throws {
        let app = XCUIApplication()
        app.launch()

        app.buttons["newNotebookButton"].tap()

        XCTAssertTrue(app.staticTexts["Untitled Notebook 1"].waitForExistence(timeout: 5))
    }

    func testTappingNotebookOpensCanvas() throws {
        let app = XCUIApplication()
        app.launch()

        app.buttons["newNotebookButton"].tap()
        app.staticTexts["Untitled Notebook 1"].tap()

        XCTAssertTrue(app.navigationBars["Untitled Notebook 1"].waitForExistence(timeout: 5))
    }
}
