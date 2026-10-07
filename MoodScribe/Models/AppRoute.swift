import Foundation

enum ComposerMode: Hashable {
    case create
    case edit(UUID)

    var navigationTitle: String {
        switch self {
        case .create: "New Reflection"
        case .edit: "Edit Reflection"
        }
    }
}

enum AppRoute: Hashable {
    case composer(ComposerMode)
    case reflection(UUID)
    case day(Date)
}
