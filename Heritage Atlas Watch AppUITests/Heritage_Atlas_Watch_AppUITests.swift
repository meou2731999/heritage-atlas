import XCTest

final class Heritage_Atlas_Watch_AppUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testEmptyStatePromptsOpeningIPhone() throws {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.staticTexts["Open Heritage Atlas on iPhone"].waitForExistence(timeout: 8))
    }
}
