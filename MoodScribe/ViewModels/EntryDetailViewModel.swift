import Foundation
import Observation

@MainActor
@Observable
final class EntryDetailViewModel {
    let entryID: UUID
    private let dataService: any DataService

    private(set) var snapshot: JournalEntrySnapshot?
    private(set) var errorMessage: String?
    private(set) var didDelete = false

    init(entryID: UUID, dataService: any DataService) {
        self.entryID = entryID
        self.dataService = dataService
    }

    func load() {
        if let entry = dataService.entry(id: entryID) {
            snapshot = JournalEntrySnapshot(entry: entry)
            errorMessage = nil
        } else {
            snapshot = nil
            errorMessage = "This entry is no longer available."
        }
    }

    func delete() {
        do {
            try dataService.delete(id: entryID)
            didDelete = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func clearError() {
        errorMessage = nil
    }
}
