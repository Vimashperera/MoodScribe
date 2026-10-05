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
    func create(text: String, date: Date, analysis: SentimentAnalysis) throws -> JournalEntry
    func update(id: UUID, text: String, analysis: SentimentAnalysis) throws
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

    func create(text: String, date: Date = .now, analysis: SentimentAnalysis) throws -> JournalEntry {
        let entry = JournalEntry(
            text: text,
            date: date,
            updatedAt: date,
            sentimentScore: analysis.score,
            sentimentLabel: analysis.label.rawValue,
            keywords: analysis.keywords
        )
        context.insert(entry)
        try context.save()
        return entry
    }

    func update(id: UUID, text: String, analysis: SentimentAnalysis) throws {
        guard let entry = entry(id: id) else { throw JournalDataError.missingEntry }
        entry.text = text
        entry.updatedAt = .now
        entry.sentimentScore = analysis.score
        entry.sentiment = analysis.label
        entry.keywords = analysis.keywords
        try context.save()
    }

    func delete(id: UUID) throws {
        guard let entry = entry(id: id) else { throw JournalDataError.missingEntry }
        context.delete(entry)
        try context.save()
    }
}
