import Foundation

enum SelectedMood: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case great = "Great"
    case good = "Good"
    case okay = "Okay"
    case low = "Low"
    case veryLow = "Very Low"

    var id: String { rawValue }
    var title: String { rawValue }

    var emoji: String {
        switch self {
        case .great: "😄"
        case .good: "🙂"
        case .okay: "😐"
        case .low: "🙁"
        case .veryLow: "😞"
        }
    }

    /// Higher means the person marked a lighter mood. This is their choice, not the writing score.
    var rank: Int {
        switch self {
        case .veryLow: 0
        case .low: 1
        case .okay: 2
        case .good: 3
        case .great: 4
        }
    }
}

enum DayFactor: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case work = "Work"
    case studies = "Studies"
    case family = "Family"
    case friends = "Friends"
    case relationships = "Relationships"
    case health = "Health"
    case money = "Money"
    case personalGoals = "Personal Goals"
    case other = "Other"

    var id: String { rawValue }
    var title: String { rawValue }

    var systemImage: String {
        switch self {
        case .work: "briefcase"
        case .studies: "book"
        case .family: "house"
        case .friends: "person.2"
        case .relationships: "heart"
        case .health: "figure.walk"
        case .money: "creditcard"
        case .personalGoals: "flag"
        case .other: "ellipsis.circle"
        }
    }
}
