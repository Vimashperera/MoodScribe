import XCTest

final class MoodScribeUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    func testCreateEntryAndVisitAllThreeScreens() {
        XCTAssertTrue(app.navigationBars["MoodScribe"].waitForExistence(timeout: 8))
        XCTAssertTrue(element("history.trend").waitForExistence(timeout: 5))
        XCTAssertTrue(element("history.calendar").waitForExistence(timeout: 5))
        XCTAssertTrue(element("history.filter.All").exists)

        element("history.newEntry").tap()

        let editor = app.textViews["composer.editor"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        XCTAssertTrue(app.navigationBars["New Entry"].exists)
        XCTAssertTrue(element("sentiment.gauge").waitForExistence(timeout: 3))
        editor.tap()
        editor.typeText("I feel happy and grateful for a wonderful calm day")

        let save = element("composer.save")
        XCTAssertTrue(save.waitForExistence(timeout: 3))
        let enabled = NSPredicate(format: "isEnabled == true")
        expectation(for: enabled, evaluatedWith: save)
        waitForExpectations(timeout: 4)
        save.tap()

        XCTAssertTrue(app.navigationBars["MoodScribe"].waitForExistence(timeout: 5))
        let row = element("history.entry")
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()

        XCTAssertTrue(app.navigationBars["Insights"].waitForExistence(timeout: 5))
        XCTAssertTrue(element("detail.score").waitForExistence(timeout: 3))
        XCTAssertTrue(element("detail.text").waitForExistence(timeout: 3))
        XCTAssertTrue(element("detail.edit").exists)
        XCTAssertTrue(element("detail.delete").exists)

        app.navigationBars["Insights"].buttons.firstMatch.tap()
        XCTAssertTrue(app.navigationBars["MoodScribe"].waitForExistence(timeout: 5))
    }

    func testSearchAndSentimentFilters() {
        let searchButton = app.buttons["Search entries"]
        let searchField = app.searchFields["Search entries"]
        if searchField.waitForExistence(timeout: 2) {
            searchField.tap()
            searchField.typeText("grateful")
        } else {
            XCTAssertTrue(searchButton.waitForExistence(timeout: 3))
            searchButton.tap()
            app.typeText("grateful")
        }

        let negative = element("history.filter.Negative")
        XCTAssertTrue(negative.waitForExistence(timeout: 3))
        XCTAssertTrue(element("history.filter.Positive").exists)
        XCTAssertTrue(element("history.filter.Neutral").exists)
        negative.tap()
        XCTAssertEqual(negative.value as? String, "selected")
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }
}
