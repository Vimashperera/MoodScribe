import SwiftUI

struct SentimentGaugeView: View {
    let score: Double
    let label: SentimentType

    @Environment(\.colorScheme) private var colorScheme
    @ScaledMetric(relativeTo: .title2) private var diameter: CGFloat = 168

    private var progress: Double {
        (min(1, max(-1, score)) + 1) / 2
    }

    private var tint: Color {
        SentimentType.interpolatedColor(for: score, scheme: colorScheme)
    }

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(Color.primary.opacity(0.08), lineWidth: diameter * 0.08)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        tint,
                        style: StrokeStyle(lineWidth: diameter * 0.08, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.55, dampingFraction: 0.78), value: progress)
                VStack(spacing: 2) {
                    Text(String(format: "%+.2f", score))
                        .font(.title2.weight(.semibold))
                        .minimumScaleFactor(0.7)
                        .contentTransition(.numericText())
                    Text("Sentiment score")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(label.rawValue)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                .padding(12)
            }
            .frame(width: diameter, height: diameter)
            .accessibilityElement(children: .ignore)
            .accessibilityIdentifier(AccessibilityID.gauge)
            .accessibilityLabel("Sentiment score")
            .accessibilityValue("\(String(format: "%+.2f", score)), \(label.rawValue) tone of the writing")
        }
    }
}

struct SentimentAuraView: View {
    let score: Double

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let tint = SentimentType.interpolatedColor(for: score, scheme: colorScheme)
        ZStack {
            Circle()
                .fill(tint.opacity(colorScheme == .dark ? 0.45 : 0.38))
                .frame(width: 280, height: 280)
                .blur(radius: 48)
            Circle()
                .fill(tint.opacity(0.25))
                .frame(width: 140, height: 140)
                .blur(radius: 18)
        }
        .animation(.easeInOut(duration: 0.35), value: score)
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }
}
