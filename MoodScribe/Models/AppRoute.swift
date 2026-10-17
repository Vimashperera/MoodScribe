import Foundation

/// Create can carry a calendar day so the saved entry stays on that day. Nil means today.
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

/// Destinations inside each tab's NavigationStack.
enum AppRoute: Hashable {
    case composer(ComposerMode)
    case reflection(UUID)
    case day(Date)
}
