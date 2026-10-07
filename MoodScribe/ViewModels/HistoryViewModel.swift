import Foundation
import Observation

enum TrendWindow: String, CaseIterable, Identifiable {
    case week = "7 Days"
    case month = "30 Days"

    var id: String { rawValue }

    var lengthInDays: Int {
        switch self {
        case .week: 7
        case .month: 30
        }
    }
}

@MainActor
@Observable
final class HistoryViewModel {
    private let dataService: any DataService
    private let calendar: Calendar

    private(set) var entries: [JournalEntrySnapshot] = []
    var query = ""
    var sentimentFilter: SentimentType?
    var selectedDay: Date?
    var visibleMonth: Date
    var trendWindow: TrendWindow = .week
    private(set) var errorMessage: String?

    init(dataService: any DataService, calendar: Calendar = .current, now: Date = .now) {
        self.dataService = dataService
        self.calendar = calendar
        self.visibleMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
    }

    var filteredEntries: [JournalEntrySnapshot] {
        Self.filter(
            entries: entries,
            query: query,
            sentiment: sentimentFilter,
            day: selectedDay,
            calendar: calendar
        )
    }

    var trendAverage: Double? {
        Self.averageScore(entries: entries, window: trendWindow, now: .now, calendar: calendar)
    }

    var trendLabel: SentimentType {
        SentimentType.classify(trendAverage ?? 0)
    }

    func reload() {
        do {
            entries = try dataService.fetchAll().map(JournalEntrySnapshot.init)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func delete(id: UUID) {
        do {
            try dataService.delete(id: id)
            reload()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func shiftMonth(by value: Int) {
        guard let next = calendar.date(byAdding: .month, value: value, to: visibleMonth) else { return }
        visibleMonth = next
    }

    func select(day: Date) {
        if let selectedDay, calendar.isDate(selectedDay, inSameDayAs: day) {
            self.selectedDay = nil
        } else {
            selectedDay = calendar.startOfDay(for: day)
        }
    }

    func clearDayFilter() {
        selectedDay = nil
    }

    func clearError() {
        errorMessage = nil
    }

    static func filter(
        entries: [JournalEntrySnapshot],
        query: String,
        sentiment: SentimentType?,
        day: Date?,
        calendar: Calendar = .current
    ) -> [JournalEntrySnapshot] {
        entries.filter { entry in
            if let sentiment, entry.sentiment != sentiment { return false }
            if let day, !calendar.isDate(entry.date, inSameDayAs: day) { return false }
            let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return true }
            if entry.text.localizedCaseInsensitiveContains(trimmed) { return true }
            if entry.sentiment.rawValue.localizedCaseInsensitiveContains(trimmed) { return true }
            if let mood = entry.mood, mood.title.localizedCaseInsensitiveContains(trimmed) { return true }
            if entry.factors.contains(where: { $0.title.localizedCaseInsensitiveContains(trimmed) }) { return true }
            return entry.keywords.contains { $0.localizedCaseInsensitiveContains(trimmed) }
        }
    }

    static func averageScore(
        entries: [JournalEntrySnapshot],
        window: TrendWindow,
        now: Date,
        calendar: Calendar = .current
    ) -> Double? {
        let startOfToday = calendar.startOfDay(for: now)
        guard let start = calendar.date(byAdding: .day, value: -(window.lengthInDays - 1), to: startOfToday) else {
            return nil
        }
        let end = calendar.date(byAdding: .day, value: 1, to: startOfToday) ?? now
        let slice = entries.filter { $0.date >= start && $0.date < end }
        guard !slice.isEmpty else { return nil }
        let total = slice.reduce(0.0) { $0 + $1.sentimentScore }
        return total / Double(slice.count)
    }

    func entries(on day: Date) -> [JournalEntrySnapshot] {
        entries.filter { calendar.isDate($0.date, inSameDayAs: day) }
    }

    func marker(on day: Date) -> DayMarker {
        let matches = entries(on: day)
        let mood = matches.sorted { $0.date > $1.date }.compactMap(\.mood).first
        let analyzed = matches.filter(\.didAnalyze)
        let sentiment: SentimentType?
        if analyzed.isEmpty {
            sentiment = nil
        } else {
            let average = analyzed.reduce(0.0) { $0 + $1.sentimentScore } / Double(analyzed.count)
            sentiment = SentimentType.classify(average)
        }
        return DayMarker(mood: mood, sentiment: sentiment, hasEntry: !matches.isEmpty)
    }
}

struct DayMarker: Equatable {
    var mood: SelectedMood?
    var sentiment: SentimentType?
    var hasEntry: Bool
}
