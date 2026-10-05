import XCTest
import SwiftData
@testable import MoodScribe

@MainActor
final class ViewModelTests: XCTestCase {
    private var container: ModelContainer!
    private var service: SwiftDataService!

    override func setUp() async throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        container = try ModelContainer(for: JournalEntry.self, configurations: configuration)
        service = SwiftDataService(context: container.mainContext)
    }

    override func tearDown() async throws {
        container = nil
        service = nil
    }

    func testSaveRejectsBlankDraftAndWritesNothing() throws {
        let viewModel = EntryComposerViewModel(mode: .create, dataService: service)
        viewModel.updateText("  ")
        viewModel.refreshAnalysis()
        XCTAssertFalse(viewModel.canSave)
        XCTAssertEqual(viewModel.validation, .empty)

        viewModel.save()
        XCTAssertFalse(viewModel.didSave)
        XCTAssertNotNil(viewModel.validationMessage)
        XCTAssertTrue(try service.fetchAll().isEmpty)
    }

    func testSavePersistsAnalysisAndHistoryReloads() throws {
        let composer = EntryComposerViewModel(mode: .create, dataService: service)
        composer.updateText("I feel wonderful, grateful, and calm today.")
        composer.refreshAnalysis()
        XCTAssertTrue(composer.canSave)
        XCTAssertGreaterThan(composer.wordCount, 0)

        composer.save()
        XCTAssertTrue(composer.didSave)

        let history = HistoryViewModel(dataService: service)
        history.reload()
        XCTAssertEqual(history.entries.count, 1)
        XCTAssertEqual(history.entries[0].text, "I feel wonderful, grateful, and calm today.")
        XCTAssertEqual(history.entries[0].sentiment, SentimentType.classify(history.entries[0].sentimentScore))
        XCTAssertGreaterThanOrEqual(history.entries[0].sentimentScore, -1)
        XCTAssertLessThanOrEqual(history.entries[0].sentimentScore, 1)
    }

    func testEditReplacesTextAndScore() throws {
        let created = try service.create(
            text: "I feel happy and grateful.",
            date: .now,
            analysis: SentimentAnalysis(score: 0.8, label: .positive, keywords: ["happy"])
        )

        let composer = EntryComposerViewModel(mode: .edit(created.id), dataService: service)
        XCTAssertEqual(composer.text, "I feel happy and grateful.")
        composer.updateText("I feel awful, sad, and hopeless.")
        composer.refreshAnalysis()
        composer.save()
        XCTAssertTrue(composer.didSave)

        let updated = try XCTUnwrap(service.entry(id: created.id))
        let expected = SentimentAnalysisService().analyze(updated.text)
        XCTAssertEqual(updated.text, "I feel awful, sad, and hopeless.")
        XCTAssertEqual(updated.sentimentScore, expected.score, accuracy: 0.001)
        XCTAssertEqual(updated.sentiment, expected.label)
    }

    func testDeleteRemovesEntryFromHistory() throws {
        let created = try service.create(
            text: "A quiet afternoon.",
            date: .now,
            analysis: SentimentAnalysis(score: 0, label: .neutral, keywords: [])
        )
        let history = HistoryViewModel(dataService: service)
        history.reload()
        XCTAssertEqual(history.entries.count, 1)

        history.delete(id: created.id)
        XCTAssertTrue(history.entries.isEmpty)
        XCTAssertNil(service.entry(id: created.id))
    }

    func testDetailLoadsAndDeletes() throws {
        let created = try service.create(
            text: "Grateful for a calm morning.",
            date: .now,
            analysis: SentimentAnalysis(score: 0.6, label: .positive, keywords: ["grateful", "calm"])
        )
        let detail = EntryDetailViewModel(entryID: created.id, dataService: service)
        detail.load()
        let snapshot = try XCTUnwrap(detail.snapshot)
        XCTAssertEqual(snapshot.keywords, ["grateful", "calm"])
        XCTAssertEqual(snapshot.sentimentScore, 0.6)

        detail.delete()
        XCTAssertTrue(detail.didDelete)
        XCTAssertNil(service.entry(id: created.id))
    }

    func testSearchAndSentimentFilter() {
        let entries = [
            snapshot("I love the sunny park", score: 0.7, keywords: ["sunny"], dayOffset: 0),
            snapshot("I feel anxious about work", score: -0.4, keywords: ["anxious"], dayOffset: -1),
            snapshot("Lunch was at noon", score: 0, keywords: ["lunch"], dayOffset: -2)
        ]

        let byWord = HistoryViewModel.filter(entries: entries, query: "park", sentiment: nil, day: nil)
        XCTAssertEqual(byWord.map(\.text), ["I love the sunny park"])

        let byKeyword = HistoryViewModel.filter(entries: entries, query: "anxious", sentiment: nil, day: nil)
        XCTAssertEqual(byKeyword.count, 1)

        let byLabel = HistoryViewModel.filter(entries: entries, query: "Positive", sentiment: nil, day: nil)
        XCTAssertEqual(byLabel.count, 1)

        let negativeOnly = HistoryViewModel.filter(entries: entries, query: "", sentiment: .negative, day: nil)
        XCTAssertEqual(negativeOnly.count, 1)
        XCTAssertEqual(negativeOnly[0].sentiment, .negative)
    }

    func testWeeklyAverageIgnoresOlderEntries() {
        let calendar = Calendar(identifier: .gregorian)
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let entries = [
            snapshot("today", score: 0.5, keywords: [], dayOffset: 0, now: now, calendar: calendar),
            snapshot("yesterday", score: -0.5, keywords: [], dayOffset: -1, now: now, calendar: calendar),
            snapshot("old", score: 1, keywords: [], dayOffset: -40, now: now, calendar: calendar)
        ]

        let average = HistoryViewModel.averageScore(entries: entries, window: .week, now: now, calendar: calendar)
        XCTAssertEqual(average ?? -99, 0, accuracy: 0.0001)

        let month = HistoryViewModel.averageScore(entries: entries, window: .month, now: now, calendar: calendar)
        XCTAssertEqual(month ?? -99, 0, accuracy: 0.0001)
        XCTAssertNil(HistoryViewModel.averageScore(entries: [], window: .week, now: now, calendar: calendar))
    }

    func testDayFilterAndMonthShift() {
        let calendar = Calendar(identifier: .gregorian)
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let history = HistoryViewModel(dataService: service, calendar: calendar, now: now)
        let originalMonth = history.visibleMonth
        history.shiftMonth(by: 1)
        XCTAssertNotEqual(history.visibleMonth, originalMonth)
        history.shiftMonth(by: -1)
        XCTAssertEqual(history.visibleMonth, originalMonth)

        let today = snapshot("today", score: 0.2, keywords: [], dayOffset: 0, now: now, calendar: calendar)
        let yesterday = snapshot("yesterday", score: -0.2, keywords: [], dayOffset: -1, now: now, calendar: calendar)
        let filtered = HistoryViewModel.filter(
            entries: [today, yesterday],
            query: "",
            sentiment: nil,
            day: calendar.startOfDay(for: now),
            calendar: calendar
        )
        XCTAssertEqual(filtered.map(\.text), ["today"])
    }

    func testMoodTagsAreIncludedInSavedText() throws {
        let composer = EntryComposerViewModel(mode: .create, dataService: service)
        composer.updateText("Today was quiet.")
        composer.toggle(.grateful)
        composer.refreshAnalysis()
        XCTAssertTrue(composer.composedText.localizedCaseInsensitiveContains("feeling grateful"))
        composer.save()

        let saved = try XCTUnwrap(service.fetchAll().first)
        XCTAssertTrue(saved.text.localizedCaseInsensitiveContains("feeling grateful"))
    }

    func testResetAndCharacterCap() {
        let composer = EntryComposerViewModel(mode: .create, dataService: service)
        composer.updateText(String(repeating: "word ", count: 800))
        composer.toggle(.calm)
        XCTAssertLessThanOrEqual(composer.characterCount, EntryComposerViewModel.maximumCharacters)
        composer.reset()
        XCTAssertEqual(composer.text, "")
        XCTAssertTrue(composer.selectedTags.isEmpty)
        XCTAssertEqual(composer.analysis, .empty)
        XCTAssertEqual(composer.validation, .empty)
    }

    func testMissingDetailEntryReportsError() {
        let detail = EntryDetailViewModel(entryID: UUID(), dataService: service)
        detail.load()
        XCTAssertNil(detail.snapshot)
        XCTAssertNotNil(detail.errorMessage)
    }

    private func snapshot(
        _ text: String,
        score: Double,
        keywords: [String],
        dayOffset: Int,
        now: Date = Date(timeIntervalSince1970: 1_700_000_000),
        calendar: Calendar = Calendar(identifier: .gregorian)
    ) -> JournalEntrySnapshot {
        let date = calendar.date(byAdding: .day, value: dayOffset, to: now) ?? now
        return JournalEntrySnapshot(
            text: text,
            date: date,
            sentimentScore: score,
            sentiment: SentimentType.classify(score),
            keywords: keywords
        )
    }
}
