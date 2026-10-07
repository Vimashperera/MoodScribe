import Foundation

enum AccessibilityID {
    static let newEntry = "history.newEntry"
    static let entryRow = "history.entry"
    static let trendCard = "history.trend"
    static let calendar = "history.calendar"
    static let editor = "composer.editor"
    static let save = "composer.save"
    static let counter = "composer.counter"
    static let gauge = "sentiment.gauge"
    static let clearDraft = "composer.clear"
    static let detailScore = "detail.score"
    static let detailEdit = "detail.edit"
    static let detailDelete = "detail.delete"
    static let detailText = "detail.text"

    static let homeWeek = "home.week"
    static let settingsAnalyze = "settings.analyze"
    static let settingsShowSentiment = "settings.showSentiment"
    static let settingsPrivacy = "settings.privacy"
    static let toneSentence = "detail.tone"

    static func moodOption(_ mood: SelectedMood) -> String {
        "mood.option.\(mood.rawValue)"
    }

    static func factor(_ factor: DayFactor) -> String {
        "factor.\(factor.rawValue)"
    }

    static func filter(_ name: String) -> String {
        "history.filter.\(name)"
    }
}
