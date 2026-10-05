import SwiftUI

enum SentimentType: String, Codable, CaseIterable, Identifiable, Sendable {
    case positive = "Positive"
    case neutral = "Neutral"
    case negative = "Negative"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .positive: "sun.max.fill"
        case .neutral: "equal.circle.fill"
        case .negative: "cloud.rain.fill"
        }
    }

    var accessibilityName: String { rawValue }

    /// Scores above 0.1 are positive, below -0.1 are negative, and the band between is neutral.
    static func classify(_ score: Double) -> SentimentType {
        if score > 0.1 { return .positive }
        if score < -0.1 { return .negative }
        return .neutral
    }

    func color(in scheme: ColorScheme) -> Color {
        Self.interpolatedColor(for: anchorScore, scheme: scheme)
    }

    static func interpolatedColor(for score: Double, scheme: ColorScheme) -> Color {
        let clamped = min(1, max(-1, score))
        let palette = scheme == .dark ? RGB.dark : RGB.light
        let mixed: RGB
        if clamped >= 0 {
            mixed = palette.neutral.mix(to: palette.positive, t: clamped)
        } else {
            mixed = palette.neutral.mix(to: palette.negative, t: -clamped)
        }
        return mixed.color
    }

    private var anchorScore: Double {
        switch self {
        case .positive: 1
        case .neutral: 0
        case .negative: -1
        }
    }
}

private struct RGB {
    var r: Double
    var g: Double
    var b: Double

    var color: Color {
        Color(red: r, green: g, blue: b)
    }

    func mix(to other: RGB, t: Double) -> RGB {
        let clamped = min(1, max(0, t))
        return RGB(
            r: r + (other.r - r) * clamped,
            g: g + (other.g - g) * clamped,
            b: b + (other.b - b) * clamped
        )
    }

    static let light = Palette(
        negative: RGB(r: 0.80, g: 0.33, b: 0.31),
        neutral: RGB(r: 0.62, g: 0.55, b: 0.22),
        positive: RGB(r: 0.11, g: 0.55, b: 0.50)
    )

    static let dark = Palette(
        negative: RGB(r: 0.95, g: 0.50, b: 0.46),
        neutral: RGB(r: 0.90, g: 0.78, b: 0.40),
        positive: RGB(r: 0.40, g: 0.84, b: 0.76)
    )

    struct Palette {
        var negative: RGB
        var neutral: RGB
        var positive: RGB
    }
}
