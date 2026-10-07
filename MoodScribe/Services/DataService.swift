import Foundation
import SwiftData

enum JournalDataError: LocalizedError {
    case missingEntry

    var errorDescription: String? {
        switch self {
        case .missingEntry:
            "That journal entry could not be found on this device."
        }
    }
}

@MainActor
protocol DataService: AnyObject {
    func fetchAll() throws -> [JournalEntry]
    func entry(id: UUID) -> JournalEntry?
    func create(
        text: String,
        date: Date,
        mood: SelectedMood?,
        factors: [DayFactor],
        analysis: SentimentAnalysis,
        didAnalyze: Bool
    ) throws -> JournalEntry
    func update(
        id: UUID,
        text: String,
        mood: SelectedMood?,
        factors: [DayFactor],
        analysis: SentimentAnalysis,
        didAnalyze: Bool
    ) throws
    func delete(id: UUID) throws
}

@MainActor
final class SwiftDataService: DataService {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func fetchAll() throws -> [JournalEntry] {
        let descriptor = FetchDescriptor<JournalEntry>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }

    func entry(id: UUID) -> JournalEntry? {
        let identifier = id
        let predicate = #Predicate<JournalEntry> { entry in
            entry.id == identifier
        }
        var descriptor = FetchDescriptor<JournalEntry>(predicate: predicate)
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    func create(
        text: String,
        date: Date = .now,
        mood: SelectedMood? = nil,
        factors: [DayFactor] = [],
        analysis: SentimentAnalysis,
        didAnalyze: Bool = true
    ) throws -> JournalEntry {
        let entry = JournalEntry(
            text: text,
            date: date,
            updatedAt: date,
            sentimentScore: didAnalyze ? analysis.score : 0,
            sentimentLabel: didAnalyze ? analysis.label.rawValue : SentimentType.neutral.rawValue,
            keywords: didAnalyze ? analysis.keywords : [],
            moodRaw: mood?.rawValue ?? "",
            factors: factors.map(\.rawValue),
            didAnalyze: didAnalyze
        )
        context.insert(entry)
        try context.save()
        return entry
    }

    func update(
        id: UUID,
        text: String,
        mood: SelectedMood?,
        factors: [DayFactor],
        analysis: SentimentAnalysis,
        didAnalyze: Bool
    ) throws {
        guard let entry = entry(id: id) else { throw JournalDataError.missingEntry }
        entry.text = text
        entry.updatedAt = .now
        entry.moodRaw = mood?.rawValue ?? ""
        entry.factors = factors.map(\.rawValue)
        entry.didAnalyze = didAnalyze
        entry.sentimentScore = didAnalyze ? analysis.score : 0
        entry.sentiment = didAnalyze ? analysis.label : .neutral
        entry.keywords = didAnalyze ? analysis.keywords : []
        try context.save()
    }

    func delete(id: UUID) throws {
        guard let entry = entry(id: id) else { throw JournalDataError.missingEntry }
        context.delete(entry)
        try context.save()
    }
}
