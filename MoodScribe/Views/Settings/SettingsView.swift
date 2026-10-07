import SwiftUI

struct SettingsView: View {
    @AppStorage(JournalPreference.analyzeAutomatically) private var analyzeAutomatically = true
    @AppStorage(JournalPreference.showSentiment) private var showSentiment = true

    var body: some View {
        Form {
            Section {
                Toggle("Analyze journal entries automatically", isOn: $analyzeAutomatically)
                    .accessibilityIdentifier(AccessibilityID.settingsAnalyze)
                Toggle("Show sentiment analysis", isOn: $showSentiment)
                    .accessibilityIdentifier(AccessibilityID.settingsShowSentiment)
            } footer: {
                Text("When analysis is off, you can still save your writing, mood, and factors. A sentiment score describes the tone of the writing. It is not a measure of mental health.")
            }

            Section("Privacy") {
                Text("Your journal entries and mood data are stored locally on your device. MoodScribe uses on-device language analysis and does not require your journal entries to be sent to an external server.")
                    .font(.body)
                    .accessibilityIdentifier(AccessibilityID.settingsPrivacy)
            }
        }
        .navigationTitle("Settings")
    }
}
