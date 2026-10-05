import SwiftUI

struct MoodTagStrip: View {
    @Binding var selectedTags: Set<MoodTag>
    var onToggle: (MoodTag) -> Void
    var onInsert: (MoodTag) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(MoodTag.allCases) { tag in
                    MoodTagChip(
                        tag: tag,
                        isSelected: selectedTags.contains(tag),
                        onToggle: { onToggle(tag) },
                        onInsert: { onInsert(tag) }
                    )
                }
            }
            .padding(.vertical, 4)
        }
        .accessibilityIdentifier("composer.moodTags")
    }
}

private struct MoodTagChip: View {
    let tag: MoodTag
    let isSelected: Bool
    var onToggle: () -> Void
    var onInsert: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var dragOffset: CGSize = .zero
    @State private var didDrag = false

    var body: some View {
        let tint = isSelected
            ? SentimentType.positive.color(in: colorScheme)
            : Color.primary.opacity(0.55)

        Label(tag.title, systemImage: tag.systemImage)
            .font(.subheadline.weight(.medium))
            .padding(.horizontal, 12)
            .frame(minHeight: 44)
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .background {
                Capsule(style: .continuous)
                    .fill(isSelected ? tint : Color.primary.opacity(0.08))
            }
            .offset(dragOffset)
            .contentShape(Capsule())
            .accessibilityIdentifier(AccessibilityID.moodTag(tag))
            .accessibilityAddTraits(.isButton)
            .accessibilityAddTraits(isSelected ? .isSelected : .isButton)
            .accessibilityHint("Tap or drag vertically to toggle. Press and hold to insert the phrase.")
            .accessibilityAction { onToggle() }
            .onTapGesture {
                if didDrag {
                    didDrag = false
                    return
                }
                onToggle()
            }
            .onLongPressGesture(minimumDuration: 0.45, perform: onInsert)
            .simultaneousGesture(
                DragGesture(minimumDistance: 16)
                    .onChanged { value in
                        dragOffset = CGSize(width: 0, height: value.translation.height)
                        if abs(value.translation.height) > 12 {
                            didDrag = true
                        }
                    }
                    .onEnded { value in
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            dragOffset = .zero
                        }
                        if abs(value.translation.height) > 28 {
                            onToggle()
                        }
                    }
            )
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isSelected)
    }
}
