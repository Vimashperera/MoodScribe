import Foundation

enum MoodTag: String, CaseIterable, Identifiable, Hashable, Sendable {
    case grateful
    case calm
    case happy
    case anxious
    case sad
    case overwhelmed

    var id: String { rawValue }

    var title: String { rawValue.capitalized }

    var phrase: String {
        switch self {
        case .grateful: "feeling grateful"
        case .calm: "feeling calm"
        case .happy: "feeling happy"
        case .anxious: "feeling anxious"
        case .sad: "feeling sad"
        case .overwhelmed: "feeling overwhelmed"
        }
    }

    var systemImage: String {
        switch self {
        case .grateful: "heart.fill"
        case .calm: "leaf.fill"
        case .happy: "sun.max.fill"
        case .anxious: "waveform.path.ecg"
        case .sad: "cloud.rain.fill"
        case .overwhelmed: "hurricane"
        }
    }
}
