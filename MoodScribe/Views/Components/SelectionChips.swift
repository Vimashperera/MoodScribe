import SwiftUI

struct MoodPicker: View {
    var selected: SelectedMood?
    var onSelect: (SelectedMood) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(SelectedMood.allCases) { mood in
                    let isSelected = selected == mood
                    Button {
                        onSelect(mood)
                    } label: {
                        VStack(spacing: 4) {
                            Text(mood.emoji)
                                .font(.title3)
                            Text(mood.title)
                                .font(.caption.weight(.medium))
                        }
                        .frame(minWidth: 72, minHeight: 64)
                        .foregroundStyle(isSelected ? Color.white : Color.primary)
                        .background {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(isSelected ? Color.accentColor : Color.primary.opacity(0.08))
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier(AccessibilityID.moodOption(mood))
                    .accessibilityLabel("\(mood.title) mood")
                    .accessibilityAddTraits(isSelected ? .isSelected : .isButton)
                    .accessibilityHint("Optional. Tap again to clear.")
                }
            }
            .padding(.vertical, 4)
        }
        .accessibilityIdentifier("composer.moods")
    }
}

struct FactorChipStrip: View {
    var selected: Set<DayFactor>
    var onToggle: (DayFactor) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(DayFactor.allCases) { factor in
                    let isSelected = selected.contains(factor)
                    Button {
                        onToggle(factor)
                    } label: {
                        Label(factor.title, systemImage: factor.systemImage)
                            .font(.subheadline.weight(.medium))
                            .padding(.horizontal, 12)
                            .frame(minHeight: 44)
                            .foregroundStyle(isSelected ? Color.white : Color.primary)
                            .background {
                                Capsule(style: .continuous)
                                    .fill(isSelected ? Color.accentColor : Color.primary.opacity(0.08))
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier(AccessibilityID.factor(factor))
                    .accessibilityAddTraits(isSelected ? .isSelected : .isButton)
                }
            }
            .padding(.vertical, 4)
        }
        .accessibilityIdentifier("composer.factors")
    }
}

struct FlexibleKeywordWrap: View {
    let keywords: [String]

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) { chips }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 88), spacing: 8)], alignment: .leading, spacing: 8) {
                chips
            }
        }
    }

    @ViewBuilder
    private var chips: some View {
        ForEach(keywords, id: \.self) { keyword in
            Text(keyword.capitalized)
                .font(.caption.weight(.medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.primary.opacity(0.08), in: Capsule())
        }
    }
}
