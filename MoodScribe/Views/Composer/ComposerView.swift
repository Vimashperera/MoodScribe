import SwiftUI
import UIKit

struct ComposerView: View {
    @Environment(\.modelContext) private var modelContext
    let mode: ComposerMode

    var body: some View {
        ComposerScreen(mode: mode, dataService: SwiftDataService(context: modelContext))
    }
}

private struct ComposerScreen: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var viewModel: EntryComposerViewModel

    init(mode: ComposerMode, dataService: any DataService) {
        _viewModel = State(initialValue: EntryComposerViewModel(mode: mode, dataService: dataService))
    }

    var body: some View {
        ScrollView {
            Group {
                if sizeClass == .regular {
                    HStack(alignment: .top, spacing: 24) {
                        editorColumn
                        insightColumn
                    }
                } else {
                    VStack(spacing: 20) {
                        insightColumn
                        editorColumn
                    }
                }
            }
            .padding()
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .navigationTitle(viewModel.navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Clear") {
                    resetWithFeedback()
                }
                .accessibilityIdentifier(AccessibilityID.clearDraft)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    viewModel.save()
                }
                .disabled(!viewModel.canSave)
                .accessibilityIdentifier(AccessibilityID.save)
            }
        }
        .onChange(of: viewModel.didSave) { _, saved in
            if saved {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                dismiss()
            }
        }
        .alert(
            "Check your entry",
            isPresented: Binding(
                get: { viewModel.validationMessage != nil },
                set: { if !$0 { viewModel.clearValidationMessage() } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.validationMessage ?? "")
        }
    }

    private var insightColumn: some View {
        VStack(spacing: 12) {
            ZStack {
                SentimentAuraView(score: viewModel.analysis.score)
                SentimentGaugeView(
                    score: viewModel.analysis.score,
                    label: viewModel.analysis.label,
                    showsResetHint: true
                )
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .onLongPressGesture(minimumDuration: 0.55) {
                resetWithFeedback()
            }
            .highPriorityGesture(
                DragGesture(minimumDistance: 24)
                    .onEnded { value in
                        if value.translation.height > 70 {
                            resetWithFeedback()
                        }
                    }
            )
            .accessibilityAction(named: "Reset draft") {
                resetWithFeedback()
            }

            if viewModel.isAnalyzing {
                ProgressView("Reading mood")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .moodCardStyle(tint: SentimentType.interpolatedColor(for: viewModel.analysis.score, scheme: colorScheme))
    }

    private var editorColumn: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("How was today?")
                .font(.title3.weight(.semibold))

            TextEditor(text: Binding(
                get: { viewModel.text },
                set: { viewModel.updateText($0) }
            ))
            .font(.body)
            .frame(minHeight: 180)
            .padding(8)
            .scrollContentBackground(.hidden)
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .accessibilityIdentifier(AccessibilityID.editor)
            .accessibilityLabel("Journal entry")

            HStack {
                Text("\(viewModel.wordCount) words")
                Spacer()
                Text("\(viewModel.characterCount)/\(EntryComposerViewModel.maximumCharacters)")
                    .foregroundStyle(viewModel.characterCount > 1_800 ? Color.orange : Color.secondary)
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
            .accessibilityIdentifier(AccessibilityID.counter)

            Text("Quick moods")
                .font(.subheadline.weight(.semibold))
            Text("Tap or drag a tag to toggle it. Press and hold a tag to insert it. Drag this caption left to clear tags.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .contentShape(Rectangle())
                .highPriorityGesture(
                    DragGesture(minimumDistance: 24)
                        .onEnded { value in
                            if value.translation.width < -60 {
                                withAnimation { viewModel.clearTags() }
                            }
                        }
                )

            MoodTagStrip(
                selectedTags: $viewModel.selectedTags,
                onToggle: { viewModel.toggle($0) },
                onInsert: { viewModel.insertPhrase(for: $0) }
            )

            if !viewModel.analysis.keywords.isEmpty {
                keywordRow
            }
        }
        .moodCardStyle(tint: .accentColor)
    }

    private var keywordRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Keywords")
                .font(.subheadline.weight(.semibold))
            FlexibleKeywordWrap(keywords: viewModel.analysis.keywords)
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
        .animation(.easeInOut(duration: 0.25), value: viewModel.analysis.keywords)
    }

    private func resetWithFeedback() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            viewModel.reset()
        }
    }
}

struct FlexibleKeywordWrap: View {
    let keywords: [String]

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                chips
            }
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
