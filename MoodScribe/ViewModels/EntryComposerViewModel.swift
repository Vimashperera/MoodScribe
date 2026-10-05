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
            "Add at least \(EntryComposerViewModel.minimumCharacters) characters so the mood check has something to read."
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
    @ObservationIgnored private var analysisTask: Task<Void, Never>?

    var text: String
    var selectedTags: Set<MoodTag>
    private(set) var analysis: SentimentAnalysis
    private(set) var didSave = false
    private(set) var validationMessage: String?
    private(set) var isAnalyzing = false

    init(
        mode: ComposerMode,
        dataService: any DataService,
        sentimentService: SentimentAnalysisService = SentimentAnalysisService()
    ) {
        self.mode = mode
        self.dataService = dataService
        self.sentimentService = sentimentService
        self.text = ""
        self.selectedTags = []
        self.analysis = .empty

        if case .edit(let id) = mode, let entry = dataService.entry(id: id) {
            text = entry.text
            analysis = SentimentAnalysis(
                score: entry.sentimentScore,
                label: entry.sentiment,
                keywords: entry.keywords
            )
        }
    }

    var navigationTitle: String { mode.navigationTitle }

    var characterCount: Int { text.count }

    var wordCount: Int {
        text.split { $0.isWhitespace }.filter { !$0.isEmpty }.count
    }

    var composedText: String {
        let body = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let extras = selectedTags
            .sorted { $0.rawValue < $1.rawValue }
            .map(\.phrase)
            .filter { phrase in
                !body.localizedCaseInsensitiveContains(phrase)
            }
        guard !extras.isEmpty else { return body }
        if body.isEmpty { return extras.joined(separator: ", ") }
        return body + "\n" + extras.joined(separator: ", ")
    }

    var validation: ComposerValidation {
        let count = composedText.count
        if composedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return .empty }
        if count < Self.minimumCharacters { return .tooShort }
        if count > Self.maximumCharacters { return .tooLong }
        return .valid
    }

    var canSave: Bool { validation == .valid }

    func updateText(_ newValue: String) {
        text = String(newValue.prefix(Self.maximumCharacters))
        scheduleAnalysis()
    }

    func toggle(_ tag: MoodTag) {
        if selectedTags.contains(tag) {
            selectedTags.remove(tag)
        } else {
            selectedTags.insert(tag)
        }
        scheduleAnalysis()
    }

    func insertPhrase(for tag: MoodTag) {
        let phrase = tag.phrase
        if text.localizedCaseInsensitiveContains(phrase) {
            selectedTags.insert(tag)
            return
        }
        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            updateText(phrase.capitalized)
        } else {
            updateText(text + " " + phrase)
        }
        selectedTags.insert(tag)
    }

    func clearTags() {
        selectedTags.removeAll()
        scheduleAnalysis()
    }

    func reset() {
        analysisTask?.cancel()
        text = ""
        selectedTags.removeAll()
        analysis = .empty
        isAnalyzing = false
        validationMessage = nil
        didSave = false
    }

    func clearValidationMessage() {
        validationMessage = nil
    }

    func refreshAnalysis() {
        analysisTask?.cancel()
        analysis = sentimentService.analyze(composedText)
        isAnalyzing = false
    }

    func save() {
        refreshAnalysis()
        guard validation == .valid else {
            validationMessage = validation.message
            return
        }
        let payload = composedText
        do {
            switch mode {
            case .create:
                _ = try dataService.create(text: payload, date: .now, analysis: analysis)
            case .edit(let id):
                try dataService.update(id: id, text: payload, analysis: analysis)
            }
            didSave = true
        } catch {
            validationMessage = error.localizedDescription
        }
    }

    private func scheduleAnalysis() {
        analysisTask?.cancel()
        isAnalyzing = true
        let snapshot = composedText
        analysisTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 160_000_000)
            guard !Task.isCancelled, let self else { return }
            let result = await SentimentAnalysisService.analyzeOffMain(snapshot)
            guard !Task.isCancelled else { return }
            guard self.composedText == snapshot else { return }
            self.analysis = result
            self.isAnalyzing = false
        }
    }
}
