import Foundation

enum MoodDirection: String, Equatable, Sendable {
    case improving = "Improving"
    case steady = "Steady"
    case lower = "Lower"
    case notEnough = "Not enough yet"
}

struct FactorCount: Equatable, Identifiable, Sendable {
    var factor: DayFactor
    var count: Int
    var id: String { factor.id }
}

struct WeekSummary: Equatable, Sendable {
    var count: Int
    var detail: String
}

enum JournalInsights {
    static let keepJournaling = "Keep journaling to discover your personal patterns."

    static func periodEntries(
        _ entries: [JournalEntrySnapshot],
        window: TrendWindow,
        now: Date,
        calendar: Calendar = .current
    ) -> [JournalEntrySnapshot] {
        let startOfToday = calendar.startOfDay(for: now)
        guard let start = calendar.date(byAdding: .day, value: -(window.lengthInDays - 1), to: startOfToday) else {
            return []
        }
        let end = calendar.date(byAdding: .day, value: 1, to: startOfToday) ?? now
        return entries.filter { $0.date >= start && $0.date < end }
    }

    static func averageAnalyzedScore(_ entries: [JournalEntrySnapshot]) -> Double? {
        let analyzed = entries.filter(\.didAnalyze)
        guard !analyzed.isEmpty else { return nil }
        let total = analyzed.reduce(0.0) { $0 + $1.sentimentScore }
        return total / Double(analyzed.count)
    }

    static func factorCounts(_ entries: [JournalEntrySnapshot]) -> [FactorCount] {
        var counts: [DayFactor: Int] = [:]
        for entry in entries {
            for factor in Set(entry.factors) {
                counts[factor, default: 0] += 1
            }
        }
        return counts
            .map { FactorCount(factor: $0.key, count: $0.value) }
            .sorted { lhs, rhs in
                if lhs.count == rhs.count { return lhs.factor.title < rhs.factor.title }
                return lhs.count > rhs.count
            }
    }

    static func repeatedKeywords(_ entries: [JournalEntrySnapshot], limit: Int = 5) -> [String] {
        var counts: [String: Int] = [:]
        for entry in entries where entry.didAnalyze {
            for keyword in Set(entry.keywords) {
                counts[keyword, default: 0] += 1
            }
        }
        return counts
            .filter { $0.value >= 2 }
            .sorted { lhs, rhs in
                if lhs.value == rhs.value { return lhs.key < rhs.key }
                return lhs.value > rhs.value
            }
            .prefix(limit)
            .map(\.key)
    }

    static func moodDirection(_ entries: [JournalEntrySnapshot]) -> MoodDirection {
        let sorted = entries
            .filter { $0.mood != nil }
            .sorted { $0.date < $1.date }
        guard sorted.count >= 2 else { return .notEnough }
        let midpoint = sorted.count / 2
        let older = sorted.prefix(midpoint)
        let newer = sorted.suffix(sorted.count - midpoint)
        let delta = averageRank(Array(newer)) - averageRank(Array(older))
        if delta > 0.5 { return .improving }
        if delta < -0.5 { return .lower }
        return .steady
    }

    /// A single comparison, only when both sides of a factor have at least two chosen moods.
    static func observation(_ entries: [JournalEntrySnapshot]) -> String? {
        let withMood = entries.filter { $0.mood != nil }
        guard withMood.count >= 4 else { return nil }

        var best: (factor: DayFactor, delta: Double)?
        for factor in DayFactor.allCases {
            let matching = withMood.filter { $0.factors.contains(factor) }
            let others = withMood.filter { !$0.factors.contains(factor) }
            guard matching.count >= 2, others.count >= 2 else { continue }
            let delta = averageRank(matching) - averageRank(others)
            guard abs(delta) >= 0.75 else { continue }
            if best == nil || abs(delta) > abs(best?.delta ?? 0) {
                best = (factor, delta)
            }
        }

        guard let best else { return nil }
        if best.delta > 0 {
            return "Your mood was generally more positive on the days you selected \(best.factor.title)."
        }
        return "Your mood was generally lower on the days you selected \(best.factor.title)."
    }

    static func weekSummary(
        entries: [JournalEntrySnapshot],
        now: Date,
        calendar: Calendar = .current
    ) -> WeekSummary {
        let slice = periodEntries(entries, window: .week, now: now, calendar: calendar)
        guard !slice.isEmpty else {
            return WeekSummary(count: 0, detail: "No reflections yet this week.")
        }

        let moods = slice.compactMap(\.mood)
        if !moods.isEmpty {
            let average = Double(moods.map(\.rank).reduce(0, +)) / Double(moods.count)
            let emoji = mostCommonMood(in: moods)?.emoji ?? "😐"
            let phrase: String
            if average >= 2.6 {
                phrase = "Mostly positive"
            } else if average <= 1.4 {
                phrase = "Mostly low"
            } else {
                phrase = "Mostly steady"
            }
            return WeekSummary(count: slice.count, detail: "\(emoji) \(phrase)")
        }

        if let score = averageAnalyzedScore(slice) {
            let title = SentimentAnalysis(score: score, label: SentimentType.classify(score), keywords: []).toneTitle
            return WeekSummary(count: slice.count, detail: title)
        }

        return WeekSummary(count: slice.count, detail: "Mood not selected")
    }

    static func greeting(for date: Date, calendar: Calendar = .current) -> String {
        switch calendar.component(.hour, from: date) {
        case 5..<12: "Good morning."
        case 12..<17: "Good afternoon."
        case 17..<22: "Good evening."
        default: "Good night."
        }
    }

    private static func averageRank(_ entries: [JournalEntrySnapshot]) -> Double {
        let ranks = entries.compactMap { $0.mood?.rank }
        guard !ranks.isEmpty else { return 0 }
        return Double(ranks.reduce(0, +)) / Double(ranks.count)
    }

    private static func mostCommonMood(in moods: [SelectedMood]) -> SelectedMood? {
        var counts: [SelectedMood: Int] = [:]
        for mood in moods {
            counts[mood, default: 0] += 1
        }
        return counts.max { lhs, rhs in
            if lhs.value == rhs.value { return lhs.key.rank < rhs.key.rank }
            return lhs.value < rhs.value
        }?.key
    }
}
