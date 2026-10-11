import Foundation
import Observation

enum ComposerValidation: Equatable {
    case valid
    case empty
    case tooShort
    case tooLong

    var message: String? {
        switch self {
        case .valid:
            nil
        case .empty:
            "Write a few words before saving."
        case .tooShort:
            "Add at least \(EntryComposerViewModel.minimumCharacters) characters so there is something to reflect on."
        case .tooLong:
            "Entries are limited to \(EntryComposerViewModel.maximumCharacters) characters."
        }
    }
}

@MainActor
@Observable
final class EntryComposerViewModel {
    static let minimumCharacters = 3
    static let maximumCharacters = 2_000

    private let dataService: any DataService
    private let sentimentService: SentimentAnalysisService
    private let mode: ComposerMode
    private var originalText = ""
    private var preservedAnalysis = SentimentAnalysis.empty
    private var preservedDidAnalyze = false

    var text: String
    var selectedMood: SelectedMood?
    var selectedFactors: Set<DayFactor>
    var analyzesAutomatically: Bool
    private(set) var analysis: SentimentAnalysis
    private(set) var didSave = false
    private(set) var savedEntryID: UUID?
    private(set) var validationMessage: String?
    private(set) var isSaving = false

    init(
        mode: ComposerMode,
        dataService: any DataService,
        sentimentService: SentimentAnalysisService = SentimentAnalysisService(),
        analyzesAutomatically: Bool = true
    ) {
        self.mode = mode
        self.dataService = dataService
        self.sentimentService = sentimentService
        self.analyzesAutomatically = analyzesAutomatically
        self.text = ""
        self.selectedMood = nil
        self.selectedFactors = []
        self.analysis = .empty

        if case .edit(let id) = mode, let entry = dataService.entry(id: id) {
            text = entry.text
            originalText = entry.text
            selectedMood = SelectedMood(rawValue: entry.moodRaw)
            selectedFactors = Set(entry.factors.compactMap(DayFactor.init(rawValue:)))
            preservedDidAnalyze = entry.didAnalyze
            let loaded = SentimentAnalysis(
                score: entry.sentimentScore,
                label: entry.sentiment,
                keywords: entry.keywords
            )
            preservedAnalysis = loaded
            analysis = entry.didAnalyze ? loaded : .empty
        }
    }

    var navigationTitle: String { mode.navigationTitle }

    /// Shown when the reflection is being written for a day other than today.
    var journalDayLabel: String? {
        guard let day = mode.journalDay else { return nil }
        let calendar = Calendar.current
        guard !calendar.isDateInToday(day) else { return nil }
        return day.formatted(date: .complete, time: .omitted)
    }

    private var entryDate: Date {
        guard let day = mode.journalDay else { return .now }
        let calendar = Calendar.current
        if calendar.isDateInToday(day) { return .now }
        let clock = calendar.dateComponents([.hour, .minute], from: .now)
        var parts = calendar.dateComponents([.year, .month, .day], from: day)
        parts.hour = clock.hour
        parts.minute = clock.minute
        return calendar.date(from: parts) ?? calendar.startOfDay(for: day)
    }

    var characterCount: Int { text.count }

    var wordCount: Int {
        text.split { $0.isWhitespace }.filter { !$0.isEmpty }.count
    }

    var bodyText: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var validation: ComposerValidation {
        let count = bodyText.count
        if bodyText.isEmpty { return .empty }
        if count < Self.minimumCharacters { return .tooShort }
        if count > Self.maximumCharacters { return .tooLong }
        return .valid
    }

    var canSave: Bool { validation == .valid }

    func updateText(_ newValue: String) {
        text = String(newValue.prefix(Self.maximumCharacters))
    }

    func select(_ mood: SelectedMood) {
        selectedMood = selectedMood == mood ? nil : mood
        refreshAnalysis()
    }

    func toggle(_ factor: DayFactor) {
        if selectedFactors.contains(factor) {
            selectedFactors.remove(factor)
        } else {
            selectedFactors.insert(factor)
        }
    }

    func clearFactors() {
        selectedFactors.removeAll()
    }

    func reset() {
        text = ""
        selectedMood = nil
        selectedFactors.removeAll()
        analysis = .empty
        validationMessage = nil
        didSave = false
        savedEntryID = nil
    }

    func clearValidationMessage() {
        validationMessage = nil
    }

    func refreshAnalysis() {
        guard analyzesAutomatically else { return }
        analysis = sentimentService.analyze(bodyText, mood: selectedMood)
    }

    func save() {
        let payload = resolveAnalysis()
        let reply = ReflectionReplyService.reply(text: bodyText, mood: selectedMood, factors: Array(selectedFactors))
        persist(payload: payload, reply: reply)
    }

    func saveWithLanguageModel() async {
        guard !isSaving else { return }
        guard validation == .valid else {
            validationMessage = validation.message
            return
        }
        isSaving = true
        defer { isSaving = false }
        let factors = selectedFactors.sorted { $0.title < $1.title }
        let interpretation = await OnDeviceJournalModel.interpret(
            text: bodyText,
            mood: selectedMood,
            factors: factors
        )
        let payload: (analysis: SentimentAnalysis, didAnalyze: Bool)
        if analyzesAutomatically {
            payload = (interpretation.analysis, true)
        } else {
            payload = resolveAnalysis()
        }
        persist(payload: payload, reply: interpretation.reply)
    }

    private func persist(
        payload: (analysis: SentimentAnalysis, didAnalyze: Bool),
        reply: ReflectionReply
    ) {
        guard validation == .valid else {
            validationMessage = validation.message
            return
        }
        let factors = selectedFactors.sorted { $0.title < $1.title }
        do {
            let savedID: UUID
            switch mode {
            case .create(day: _):
                let entry = try dataService.create(
                    text: bodyText,
                    date: entryDate,
                    mood: selectedMood,
                    factors: factors,
                    analysis: payload.analysis,
                    didAnalyze: payload.didAnalyze
                )
                savedID = entry.id
            case .edit(let id):
                try dataService.update(
                    id: id,
                    text: bodyText,
                    mood: selectedMood,
                    factors: factors,
                    analysis: payload.analysis,
                    didAnalyze: payload.didAnalyze
                )
                savedID = id
            }
            try dataService.setReply(id: savedID, title: reply.title, message: reply.message, tone: reply.tone)
            savedEntryID = savedID
            didSave = true
        } catch {
            validationMessage = error.localizedDescription
        }
    }

    private func resolveAnalysis() -> (analysis: SentimentAnalysis, didAnalyze: Bool) {
        if analyzesAutomatically {
            refreshAnalysis()
            return (analysis, true)
        }
        let textChanged = bodyText != originalText.trimmingCharacters(in: .whitespacesAndNewlines)
        if case .edit = mode, !textChanged, preservedDidAnalyze {
            analysis = preservedAnalysis
            return (preservedAnalysis, true)
        }
        analysis = .empty
        return (.empty, false)
    }
}
