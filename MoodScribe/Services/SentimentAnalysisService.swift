import Foundation
import NaturalLanguage

struct SentimentAnalysisService: Sendable {
    private let maximumKeywords = 6

    func analyze(_ text: String, mood: SelectedMood? = nil) -> SentimentAnalysis {
        read(text, mood: mood).analysis
    }

    /// Sentence-by-sentence reading of the entry, using the same judgment as `analyze`.
    func sentenceReadings(for text: String) -> [SentenceReading] {
        read(text).sentences
    }

    func read(_ text: String, mood: SelectedMood? = nil) -> SentimentReading {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            if let mood {
                let score = mood.sentimentScore
                return SentimentReading(
                    analysis: SentimentAnalysis(
                        score: score,
                        label: SentimentType.classify(score),
                        keywords: []
                    ),
                    sentences: []
                )
            }
            return SentimentReading(analysis: .empty, sentences: [])
        }

        let scorer = SentenceScorer(text: trimmed)
        let sentences = scorer.scoredSentences()
        let textScore = scorer.documentScore(from: sentences)
        let score = Self.blend(textScore, mood: mood)
        return SentimentReading(
            analysis: SentimentAnalysis(
                score: score,
                label: SentimentType.classify(score),
                keywords: extractKeywords(from: trimmed)
            ),
            sentences: sentences
        )
    }

    static func analyzeOffMain(_ text: String, mood: SelectedMood? = nil) async -> SentimentAnalysis {
        let service = SentimentAnalysisService()
        return await Task.detached(priority: .userInitiated) {
            service.analyze(text, mood: mood)
        }.value
    }

    private static func blend(_ textScore: Double, mood: SelectedMood?) -> Double {
        let final: Double
        if let mood {
            let moodScore = mood.sentimentScore
            if abs(textScore) < 0.15 {
                final = 0.25 * textScore + 0.75 * moodScore
            } else {
                final = 0.50 * textScore + 0.50 * moodScore
            }
        } else {
            final = textScore
        }
        let clamped = min(1.0, max(-1.0, final))
        return (clamped * 1000).rounded() / 1000
    }

    func extractKeywords(from text: String) -> [String] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        let tagger = NLTagger(tagSchemes: [.lexicalClass, .lemma])
        tagger.string = trimmed
        let range = trimmed.startIndex..<trimmed.endIndex
        tagger.setLanguage(Self.dominantLanguage(for: trimmed), range: range)

        var scores: [String: Int] = [:]
        tagger.enumerateTags(
            in: range,
            unit: .word,
            scheme: .lemma,
            options: [.omitWhitespace, .omitPunctuation, .joinNames]
        ) { lemmaTag, tokenRange in
            let surface = String(trimmed[tokenRange]).lowercased()
            let lemma = lemmaTag?.rawValue.lowercased() ?? surface
            let token = lemma.filter(\.isLetter)
            guard token.count > 2, !Self.stopWords.contains(token) else { return true }

            let (classTag, _) = tagger.tag(at: tokenRange.lowerBound, unit: .word, scheme: .lexicalClass)
            let isContent = classTag == .adjective || classTag == .noun || classTag == .verb
            let isEmotion = Self.emotionLexicon.contains(token) || Self.emotionLexicon.contains(surface)

            if isEmotion {
                scores[token, default: 0] += 5
            } else if isContent {
                scores[token, default: 0] += 1
            }
            return true
        }

        return scores
            .sorted { lhs, rhs in
                if lhs.value == rhs.value { return lhs.key < rhs.key }
                return lhs.value > rhs.value
            }
            .prefix(maximumKeywords)
            .map(\.key)
    }

    fileprivate static func dominantLanguage(for text: String) -> NLLanguage {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        return recognizer.dominantLanguage ?? .english
    }

    fileprivate static func sentences(in text: String) -> [String] {
        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = text
        var result: [String] = []
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let sentence = text[range].trimmingCharacters(in: .whitespacesAndNewlines)
            if !sentence.isEmpty {
                result.append(sentence)
            }
            return true
        }
        if result.isEmpty {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { return [trimmed] }
        }
        return result
    }

    fileprivate static func clamp(_ value: Double) -> Double {
        min(1, max(-1, value))
    }

    /// Opens a compressed on-device score so a clearly tilted sentence can leave the neutral band.
    fileprivate static func expand(_ raw: Double) -> Double {
        let magnitude = min(1, abs(raw))
        guard magnitude >= 0.02 else { return 0 }
        let lifted = 1 - exp(-2.2 * magnitude)
        return (raw < 0 ? -1 : 1) * min(1, lifted)
    }

    fileprivate static let stopWords: Set<String> = [
        "the", "and", "but", "for", "with", "this", "that", "from", "have", "has", "had",
        "was", "were", "are", "been", "being", "you", "your", "yours", "myself", "just",
        "very", "really", "today", "feel", "feeling", "felt", "into", "about", "because",
        "there", "their", "they", "them", "then", "than", "what", "when", "where", "which",
        "while", "would", "could", "should", "also", "some", "more", "most", "much", "like"
    ]

    fileprivate static let positiveLexicon: [String: Double] = [
        "wonderful": 1.0, "fantastic": 1.0, "amazing": 1.0, "awesome": 1.0, "excellent": 1.0,
        "super": 0.8, "fabulous": 1.0, "love": 0.9, "loved": 0.9, "loving": 0.9,
        "thrilled": 1.0, "joy": 0.9, "joyful": 0.9, "delighted": 0.9, "blessed": 0.9,
        "happy": 0.8, "happiness": 0.8, "grateful": 0.8, "gratitude": 0.8, "calm": 0.6,
        "peaceful": 0.7, "peace": 0.6, "hope": 0.6, "hopeful": 0.7, "excited": 0.8,
        "excitement": 0.8, "proud": 0.7, "content": 0.6, "relaxed": 0.6, "relax": 0.5,
        "relaxing": 0.6, "optimistic": 0.7, "great": 0.8, "good": 0.6, "better": 0.5,
        "best": 0.8, "calmness": 0.6, "relief": 0.6, "relieved": 0.6, "thankful": 0.8,
        "fine": 0.4, "nice": 0.6, "fun": 0.7, "enjoy": 0.7, "enjoyed": 0.7, "enjoying": 0.7,
        "pleasant": 0.6, "productive": 0.6, "satisfying": 0.6, "accomplished": 0.7,
        "cheer": 0.6, "cheerful": 0.7, "serene": 0.7, "energized": 0.7, "inspired": 0.7,
        "glad": 0.6, "cool": 0.4, "sweet": 0.5, "special": 0.5, "well": 0.4, "smile": 0.6,
        "smiled": 0.6, "smiling": 0.6, "laugh": 0.7, "laughed": 0.7, "laughing": 0.7,
        "refreshing": 0.6, "refreshed": 0.6, "comfortable": 0.5, "cozy": 0.5,
        "friendly": 0.5, "kind": 0.5, "kindness": 0.6, "helpful": 0.5, "brilliant": 0.8,
        "favorite": 0.6, "positive": 0.6, "strong": 0.4, "healthy": 0.5, "peacefully": 0.7,
        "lovely": 0.7, "beautiful": 0.7, "pleased": 0.6, "win": 0.6, "won": 0.6,
        "success": 0.6, "successful": 0.7, "meaningful": 0.5, "bright": 0.5
    ]

    fileprivate static let negativeLexicon: [String: Double] = [
        "terrible": -1.0, "awful": -1.0, "horrible": -1.0, "miserable": -1.0,
        "depressed": -1.0, "depression": -1.0, "hopeless": -1.0, "furious": -1.0,
        "hate": -0.9, "hated": -0.9, "hating": -0.9, "disgusted": -0.9, "devastated": -1.0,
        "sad": -0.7, "sadness": -0.7, "angry": -0.8, "anger": -0.8, "mad": -0.7,
        "anxious": -0.7, "anxiety": -0.7, "afraid": -0.7, "fear": -0.7, "fearful": -0.7,
        "worried": -0.6, "worry": -0.6, "stress": -0.6, "stressed": -0.7, "stressful": -0.7,
        "overwhelmed": -0.8, "hurt": -0.7, "pain": -0.7, "painful": -0.7, "guilty": -0.6,
        "guilt": -0.6, "shame": -0.7, "ashamed": -0.7, "frustrated": -0.7, "frustration": -0.7,
        "tired": -0.4, "exhausted": -0.6, "drained": -0.6, "bad": -0.7, "worst": -1.0,
        "worse": -0.6, "upset": -0.7, "annoyed": -0.6, "annoying": -0.6, "gloomy": -0.6,
        "disappointed": -0.7, "sick": -0.5, "bored": -0.4, "nervous": -0.5, "dread": -0.8,
        "poor": -0.5, "lonely": -0.7, "loneliness": -0.7, "fail": -0.7, "failed": -0.7, "failure": -0.8,
        "unhappy": -0.7, "grief": -0.8, "sorrow": -0.8, "regret": -0.6, "trouble": -0.5,
        "hard": -0.3, "crying": -0.6, "cry": -0.6, "tears": -0.5, "negative": -0.6,
        "empty": -0.4, "stuck": -0.5, "broken": -0.6, "lost": -0.4, "rough": -0.4
    ]

    fileprivate static let negationWords: Set<String> = [
        "not", "no", "never", "hardly", "barely", "scarcely", "without",
        "isnt", "isn't", "wasnt", "wasn't", "arent", "aren't", "werent", "weren't",
        "dont", "don't", "doesnt", "doesn't", "didnt", "didn't",
        "wont", "won't", "wouldnt", "wouldn't", "cant", "can't", "cannot",
        "couldnt", "couldn't", "shouldnt", "shouldn't"
    ]

    fileprivate static let emotionLexicon: Set<String> = [
        "happy", "happiness", "joy", "joyful", "grateful", "gratitude", "calm", "peaceful",
        "peace", "love", "loved", "loving", "hope", "hopeful", "excited", "excitement",
        "proud", "content", "relaxed", "optimistic", "wonderful", "great", "good", "better",
        "sad", "sadness", "angry", "anger", "anxious", "anxiety", "hopeless", "terrible",
        "awful", "miserable", "depressed", "depression", "lonely", "loneliness", "afraid",
        "fear", "worried", "worry", "stress", "stressed", "overwhelmed", "hurt", "pain",
        "painful", "guilty", "guilt", "shame", "ashamed", "frustrated", "frustration",
        "tired", "exhausted", "calmness", "relief", "relieved", "thankful"
    ]

    fileprivate static let intensifiers: [String: Double] = [
        "so": 1.35, "very": 1.25, "really": 1.25, "extremely": 1.6, "incredibly": 1.55,
        "super": 1.4, "truly": 1.3, "deeply": 1.35, "absolutely": 1.45, "totally": 1.3
    ]

    fileprivate static let diminishers: Set<String> = [
        "slightly", "somewhat", "kinda", "fairly", "pretty", "bit", "little"
    ]

    fileprivate static let contrastWords: Set<String> = ["but", "however", "yet"]

    fileprivate static let englishEmbedding = NLEmbedding.wordEmbedding(for: .english)

    fileprivate static let positivePole: [Double]? = pole(from: [
        "happy", "grateful", "joyful", "peaceful", "hopeful", "wonderful",
        "love", "calm", "proud", "excited", "glad", "smile"
    ])

    fileprivate static let negativePole: [Double]? = pole(from: [
        "sad", "angry", "anxious", "hopeless", "terrible", "miserable",
        "afraid", "lonely", "stressed", "hurt", "awful", "hate"
    ])

    private static func pole(from words: [String]) -> [Double]? {
        guard let embedding = englishEmbedding else { return nil }
        var sum: [Double] = []
        var count = 0
        for word in words {
            guard let vector = embedding.vector(for: word) else { continue }
            if sum.isEmpty {
                sum = Array(repeating: 0, count: vector.count)
            }
            guard sum.count == vector.count else { continue }
            for index in sum.indices {
                sum[index] += vector[index]
            }
            count += 1
        }
        guard count >= 4 else { return nil }
        return sum.map { $0 / Double(count) }
    }
}

/// Scores each sentence as one unit: Apple's sentence model, the meaning of nearby words, and clause shape.
private final class SentenceScorer {
    private let text: String
    private let language: NLLanguage
    private var vectorCache: [String: [Double]] = [:]

    init(text: String) {
        self.text = text
        self.language = SentimentAnalysisService.dominantLanguage(for: text)
    }

    func scoredSentences() -> [SentenceReading] {
        SentimentAnalysisService.sentences(in: text).map { sentence in
            SentenceReading(text: sentence, score: scoreChunk(sentence))
        }
    }

    func documentScore(from sentences: [SentenceReading]) -> Double {
        let pairs = sentences.map { ($0.text, $0.score) }
        let aggregate = emphasize(pairs)
        guard sentences.count > 1 else { return aggregate }
        let whole = scoreChunk(text)
        if abs(aggregate) < 0.08 { return max(whole, aggregate) }
        if whole == 0 { return aggregate }
        if whole * aggregate > 0 {
            return abs(whole) > abs(aggregate) ? whole : aggregate
        }
        return aggregate
    }

    private func scoreChunk(_ chunk: String) -> Double {
        let model = modelScore(for: chunk)
        let composed = compositionalScore(for: chunk)
        let embedded = embeddingScore(for: chunk)
        return combine(model: model, composed: composed, embedded: embedded, chunk: chunk)
    }

    /// NLTagger's sentiment scheme reads the sentence, not a bag of matching words.
    private func modelScore(for chunk: String) -> Double? {
        let tagger = NLTagger(tagSchemes: [.sentimentScore])
        tagger.string = chunk
        let range = chunk.startIndex..<chunk.endIndex
        tagger.setLanguage(language, range: range)
        let value = averageScore(tagger: tagger, text: chunk, unit: .sentence)
            ?? averageScore(tagger: tagger, text: chunk, unit: .paragraph)
        guard let value, abs(value) > 0.001 else { return nil }
        return value
    }

    private func averageScore(tagger: NLTagger, text: String, unit: NLTokenUnit) -> Double? {
        var weightedSum = 0.0
        var totalWeight = 0.0
        tagger.enumerateTags(
            in: text.startIndex..<text.endIndex,
            unit: unit,
            scheme: .sentimentScore,
            options: [.omitWhitespace]
        ) { tag, tokenRange in
            if let tag, let value = Double(tag.rawValue) {
                let weight = Double(text.distance(from: tokenRange.lowerBound, to: tokenRange.upperBound))
                weightedSum += value * max(weight, 1)
                totalWeight += max(weight, 1)
            }
            return true
        }
        guard totalWeight > 0 else { return nil }
        return weightedSum / totalWeight
    }

    /// Clause shape: negation, intensifiers, and a later "but" outweigh the opening clause.
    private func compositionalScore(for chunk: String) -> Double? {
        let tokens = tokens(in: chunk)
        guard !tokens.isEmpty else { return nil }

        var score = 0.0
        var weight = 0.0
        var pendingScale = 1.0
        var negationLeft = 0

        for token in tokens {
            if SentimentAnalysisService.contrastWords.contains(token.surface)
                || SentimentAnalysisService.contrastWords.contains(token.lemma) {
                score *= 0.2
                weight *= 0.2
                negationLeft = 0
                pendingScale = 1
                continue
            }
            if isNegation(token.surface) || isNegation(token.lemma) {
                negationLeft = 4
                continue
            }
            if let boost = SentimentAnalysisService.intensifiers[token.surface]
                ?? SentimentAnalysisService.intensifiers[token.lemma] {
                pendingScale = boost
                continue
            }
            if SentimentAnalysisService.diminishers.contains(token.surface)
                || SentimentAnalysisService.diminishers.contains(token.lemma) {
                pendingScale = 0.65
                continue
            }
            guard let polarity = polarity(surface: token.surface, lemma: token.lemma) else {
                if negationLeft > 0 { negationLeft -= 1 }
                continue
            }
            var value = polarity * pendingScale
            if negationLeft > 0 {
                value = -value * 0.9
                negationLeft = 0
            }
            score += value
            weight += 1
            pendingScale = 1
        }

        guard weight > 0 else { return nil }
        return SentimentAnalysisService.clamp(score / weight)
    }

    /// Compares the sentence's words, as vectors, with positive and negative meaning.
    private func embeddingScore(for chunk: String) -> Double? {
        guard language == .english,
              let embedding = SentimentAnalysisService.englishEmbedding,
              let positive = SentimentAnalysisService.positivePole,
              let negative = SentimentAnalysisService.negativePole else { return nil }

        let words = contentWords(in: chunk)
        guard words.count >= 3, let center = centroid(of: words, embedding: embedding) else { return nil }
        let delta = cosine(center, positive) - cosine(center, negative)
        guard abs(delta) >= 0.07 else { return nil }
        let scaled = tanh(delta * 3.4)
        guard abs(scaled) >= 0.22 else { return nil }
        return SentimentAnalysisService.clamp(scaled)
    }

    private func combine(model: Double?, composed: Double?, embedded: Double?, chunk: String) -> Double {
        guard let composed else {
            // No clause evidence. A positive sentence model or meaning vector can still lift it.
            // A negative vector, on its own, must not mark a plain note as low.
            if let embedded, embedded >= 0.22 {
                if let model, model > 0 {
                    return SentimentAnalysisService.clamp(0.65 * embedded + 0.35 * SentimentAnalysisService.expand(model))
                }
                return SentimentAnalysisService.clamp(embedded)
            }
            if let model, model > 0.1 {
                return SentimentAnalysisService.clamp(SentimentAnalysisService.expand(model))
            }
            if let model, model > 0 {
                return SentimentAnalysisService.clamp(model)
            }
            return 0
        }

        if containsContrast(chunk) {
            if let model, composed * model < 0 {
                return SentimentAnalysisService.clamp(0.8 * composed + 0.2 * SentimentAnalysisService.expand(model))
            }
            if model == nil || abs(model ?? 0) < 0.05 {
                return SentimentAnalysisService.clamp(composed)
            }
        }

        var modelValue = model
        if let modelValueUnwrapped = modelValue,
           modelValueUnwrapped < 0,
           modelValueUnwrapped > -0.55,
           composed > -0.05,
           (embedded ?? 0) >= -0.05 {
            modelValue = nil
        }

        if let modelValue, abs(modelValue) >= 0.02 {
            let expanded = SentimentAnalysisService.expand(modelValue)
            if composed * modelValue < 0, abs(composed) >= 0.3 {
                return SentimentAnalysisService.clamp(0.7 * composed + 0.3 * expanded)
            }
            var score = 0.7 * expanded + 0.3 * composed
            if let embedded, abs(embedded) >= 0.22 {
                if embedded * score < 0, abs(embedded) > abs(score) {
                    score = 0.6 * embedded + 0.4 * score
                } else if embedded * score >= 0 {
                    score = 0.8 * score + 0.2 * embedded
                }
            }
            return SentimentAnalysisService.clamp(score)
        }

        if let embedded, abs(embedded) >= 0.22 {
            if composed * embedded < 0 {
                return SentimentAnalysisService.clamp(abs(composed) >= abs(embedded) ? composed : embedded)
            }
            return SentimentAnalysisService.clamp(0.55 * composed + 0.45 * embedded)
        }
        return SentimentAnalysisService.clamp(composed)
    }

    private func emphasize(_ pairs: [(String, Double)]) -> Double {
        var weighted = 0.0
        var weight = 0.0
        for (sentence, score) in pairs {
            let magnitude = abs(score)
            let emphasis = magnitude < 0.08 ? 0.25 : (1.4 + magnitude)
            let sampleWeight = Double(max(sentence.count, 1)) * emphasis
            weighted += score * sampleWeight
            weight += sampleWeight
        }
        guard weight > 0 else { return 0 }
        return SentimentAnalysisService.clamp(weighted / weight)
    }

    private func tokens(in chunk: String) -> [(surface: String, lemma: String)] {
        let tagger = NLTagger(tagSchemes: [.lemma])
        tagger.string = chunk
        let range = chunk.startIndex..<chunk.endIndex
        tagger.setLanguage(language, range: range)
        var tokens: [(surface: String, lemma: String)] = []
        tagger.enumerateTags(
            in: range,
            unit: .word,
            scheme: .lemma,
            options: [.omitWhitespace, .omitPunctuation]
        ) { lemmaTag, tokenRange in
            let surface = String(chunk[tokenRange]).lowercased()
            let lemma = lemmaTag?.rawValue.lowercased() ?? surface
            tokens.append((surface, lemma))
            return true
        }
        return tokens
    }

    private func polarity(surface: String, lemma: String) -> Double? {
        if let value = SentimentAnalysisService.positiveLexicon[surface]
            ?? SentimentAnalysisService.positiveLexicon[lemma] {
            return value
        }
        return SentimentAnalysisService.negativeLexicon[surface]
            ?? SentimentAnalysisService.negativeLexicon[lemma]
    }

    private func isNegation(_ token: String) -> Bool {
        if SentimentAnalysisService.negationWords.contains(token) { return true }
        return token == "n't" || token.hasSuffix("n't")
    }

    private func containsContrast(_ chunk: String) -> Bool {
        let lowered = " \(chunk.lowercased()) "
        return SentimentAnalysisService.contrastWords.contains { word in
            lowered.contains(" \(word) ")
        }
    }

    private func contentWords(in chunk: String) -> [String] {
        tokens(in: chunk).compactMap { token in
            let word = token.lemma.filter(\.isLetter)
            guard word.count > 2, !SentimentAnalysisService.stopWords.contains(word) else { return nil }
            return word
        }
    }

    private func centroid(of words: [String], embedding: NLEmbedding) -> [Double]? {
        var sum: [Double] = []
        var count = 0
        for word in words {
            guard let vector = cachedVector(for: word, embedding: embedding) else { continue }
            if sum.isEmpty {
                sum = Array(repeating: 0, count: vector.count)
            }
            guard sum.count == vector.count else { continue }
            for index in sum.indices {
                sum[index] += vector[index]
            }
            count += 1
        }
        guard count >= 3 else { return nil }
        return sum.map { $0 / Double(count) }
    }

    private func cachedVector(for word: String, embedding: NLEmbedding) -> [Double]? {
        if let cached = vectorCache[word] {
            return cached
        }
        guard let vector = embedding.vector(for: word) else { return nil }
        vectorCache[word] = vector
        return vector
    }

    private func cosine(_ lhs: [Double], _ rhs: [Double]) -> Double {
        guard lhs.count == rhs.count, !lhs.isEmpty else { return 0 }
        var dot = 0.0
        var leftNorm = 0.0
        var rightNorm = 0.0
        for index in lhs.indices {
            dot += lhs[index] * rhs[index]
            leftNorm += lhs[index] * lhs[index]
            rightNorm += rhs[index] * rhs[index]
        }
        let denominator = (leftNorm * rightNorm).squareRoot()
        guard denominator > 0 else { return 0 }
        return dot / denominator
    }
}
