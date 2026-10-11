import Foundation

enum ComposerMode: Hashable {
    /// `day` is the calendar day the reflection belongs to. Nil means today.
    case create(day: Date?)
    case edit(UUID)

    var navigationTitle: String {
        switch self {
        case .create(day: _):
            return "New Reflection"
        case .edit:
            return "Edit Reflection"
        }
    }

    var journalDay: Date? {
        if case .create(let day) = self { return day }
        return nil
    }
}

enum AppRoute: Hashable {
    case composer(ComposerMode)
    case reflection(UUID)
    case day(Date)
}
