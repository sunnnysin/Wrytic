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

    /// The system Photos/Files pickers presented by the menu's two options
    /// run out-of-process and can't be reliably driven in CI (no seeded
    /// photo library, permission prompts vary by simulator state) — this
    /// covers what's actually testable: the insert-image entry point exists
    /// on the canvas toolbar and offers both sources.
    func testInsertImageMenuOffersPhotoLibraryAndFiles() throws {
        let app = XCUIApplication()
        app.launch()

        app.buttons["newNotebookButton"].tap()
        app.staticTexts["Untitled Notebook 1"].tap()
        XCTAssertTrue(app.navigationBars["Untitled Notebook 1"].waitForExistence(timeout: 5))

        app.buttons["insertImageMenu"].tap()

        XCTAssertTrue(app.buttons["Photo Library"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Files"].waitForExistence(timeout: 5))
    }
}
