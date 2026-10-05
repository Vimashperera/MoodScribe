import Foundation

enum ComposerMode: Hashable {
    case create
    case edit(UUID)

    var navigationTitle: String {
        switch self {
        case .create: "New Entry"
        case .edit: "Edit Entry"
        }
    }
}

enum AppRoute: Hashable {
    case composer(ComposerMode)
    case detail(UUID)
}
