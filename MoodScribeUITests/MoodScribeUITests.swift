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

    func testCreateReflectionAndOpenIt() {
        XCTAssertTrue(app.navigationBars["MoodScribe"].waitForExistence(timeout: 8))
        XCTAssertTrue(element("home.week").waitForExistence(timeout: 5))

        element("history.newEntry").tap()

        let editor = app.textViews["composer.editor"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        XCTAssertTrue(app.navigationBars["New Reflection"].exists)
        XCTAssertFalse(element("sentiment.gauge").exists)
        element("mood.option.Good").tap()
        editor.tap()
        editor.typeText("I feel happy and grateful for a wonderful calm day")

        let save = element("composer.save")
        XCTAssertTrue(save.waitForExistence(timeout: 3))
        expectation(for: NSPredicate(format: "isEnabled == true"), evaluatedWith: save)
        waitForExpectations(timeout: 4)
        save.tap()

        let reflectionBar = app.navigationBars["Today's Reflection"]
        XCTAssertTrue(reflectionBar.waitForExistence(timeout: 5))
        XCTAssertTrue(element("sentiment.gauge").waitForExistence(timeout: 3))
        XCTAssertTrue(element("detail.score").waitForExistence(timeout: 3))
        XCTAssertTrue(element("detail.tone").waitForExistence(timeout: 3))
        XCTAssertTrue(element("detail.text").waitForExistence(timeout: 3))
        XCTAssertTrue(element("detail.edit").exists)
        XCTAssertTrue(element("detail.delete").exists)

        reflectionBar.buttons.firstMatch.tap()
        XCTAssertTrue(app.navigationBars["MoodScribe"].waitForExistence(timeout: 5))
        XCTAssertTrue(element("history.entry").waitForExistence(timeout: 5))
    }

    func testCalendarSearchFiltersAndEmptyDay() {
        app.tabBars.buttons["Calendar"].tap()
        XCTAssertTrue(app.navigationBars["Calendar"].waitForExistence(timeout: 5))
        XCTAssertTrue(element("history.calendar").waitForExistence(timeout: 5))

        let searchField = app.searchFields["Search entries"]
        let searchButton = app.buttons["Search entries"]
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

    func testSettingsExplainPrivacyAndAnalysis() {
        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        XCTAssertTrue(element("settings.analyze").waitForExistence(timeout: 3))
        XCTAssertTrue(element("settings.showSentiment").exists)
        XCTAssertTrue(element("settings.privacy").exists)
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }
}
