import SwiftUI
import UIKit

struct ComposerView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage(JournalPreference.analyzeAutomatically) private var analyzeAutomatically = true

    let mode: ComposerMode
    var onSaved: (UUID) -> Void

    var body: some View {
        ComposerScreen(
            mode: mode,
            dataService: SwiftDataService(context: modelContext),
            analyzeAutomatically: analyzeAutomatically,
            onSaved: onSaved
        )
    }
}

enum JournalPreference {
    static let analyzeAutomatically = "moodscribe.analyzeAutomatically"
    static let showSentiment = "moodscribe.showSentiment"
}

private struct ComposerScreen: View {
    @State private var viewModel: EntryComposerViewModel
    var analyzeAutomatically: Bool
    var onSaved: (UUID) -> Void

    init(
        mode: ComposerMode,
        dataService: any DataService,
        analyzeAutomatically: Bool,
        onSaved: @escaping (UUID) -> Void
    ) {
        self.analyzeAutomatically = analyzeAutomatically
        _viewModel = State(initialValue: EntryComposerViewModel(
            mode: mode,
            dataService: dataService,
            analyzesAutomatically: analyzeAutomatically
        ))
        self.onSaved = onSaved
    }

    var body: some View {
        ScrollView {
            editorColumn
                .padding()
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .navigationTitle(viewModel.navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Clear") { resetWithFeedback() }
                    .accessibilityIdentifier(AccessibilityID.clearDraft)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { viewModel.save() }
                    .disabled(!viewModel.canSave)
                    .accessibilityIdentifier(AccessibilityID.save)
            }
        }
        .onChange(of: viewModel.didSave) { _, saved in
            guard saved, let id = viewModel.savedEntryID else { return }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            onSaved(id)
        }
        .onChange(of: analyzeAutomatically) { _, newValue in
            viewModel.analyzesAutomatically = newValue
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

    private var editorColumn: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("How was your day?")
                .font(.title3.weight(.semibold))

            TextEditor(text: Binding(
                get: { viewModel.text },
                set: { viewModel.updateText($0) }
            ))
            .font(.body)
            .frame(minHeight: 180)
            .padding(8)
            .scrollContentBackground(.hidden)
            .background(
                Color(uiColor: .secondarySystemGroupedBackground),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
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

            Text("Mood")
                .font(.subheadline.weight(.semibold))
            Text("Optional. This is how you felt, separate from the tone of the writing.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            MoodPicker(selected: viewModel.selectedMood) { viewModel.select($0) }

            Text("What influenced your day?")
                .font(.subheadline.weight(.semibold))
            Text("Optional. Drag this caption left to clear the factors.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .contentShape(Rectangle())
                .highPriorityGesture(
                    DragGesture(minimumDistance: 24)
                        .onEnded { value in
                            if value.translation.width < -60 {
                                withAnimation { viewModel.clearFactors() }
                            }
                        }
                )
            FactorChipStrip(selected: viewModel.selectedFactors) { viewModel.toggle($0) }
        }
        .moodCardStyle(tint: .accentColor)
    }

    private func resetWithFeedback() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            viewModel.reset()
        }
    }
}
