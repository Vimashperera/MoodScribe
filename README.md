# MoodScribe

MoodScribe is a personal journaling and well-being app. You write about your day, choose how you felt, and optionally note what influenced the day. On-device language analysis describes the tone of the writing. Entries stay in a local SwiftData store.

The sentiment score is the emotional tone of the words you wrote. It is not a measurement of mental health, and the app does not diagnose or treat anything.

The app is the SE4041 (Mobile Application Design and Development) Part A submission. The interface is SwiftUI, the language is Swift 5, and the deployment target is iOS 17.

## What you can do

1. **Home.** A greeting, a New Reflection button, the latest entries, and a short line about this week.
2. **Composer.** A prompt, "How was your day?", an optional mood (Great through Very Low), and optional factors such as Studies or Work. The writing tone is calculated when you save, not while you type.
3. **Reflection.** After you save, the app shows the writing, your mood, your factors, and — when analysis is on — a sentence such as "Your writing has a slightly positive tone," plus the sentiment score.
4. **Calendar.** Each day with a reflection shows the mood you chose and a tone marker. An empty day says no reflection was recorded.
5. **Trends.** Week or month mood direction, average writing tone, common factors, and a short summary. Observations appear only when the stored entries support them.
6. **Settings.** Turn automatic analysis on or off, hide or show sentiment, and read the on-device privacy note.

Use Clear to reset a draft. Drag the factor caption left to clear selected factors. Drag the calendar sideways, or use the chevrons, to change month.

On a regular-width iPad layout the reflection screen places the writing and the insight panels side by side. On iPhone they stack. Home keeps a comfortable reading width on iPad.

## Architecture

MoodScribe uses MVVM. Views render state and forward actions. View models own validation, filtering, and save rules. Services own Natural Language and SwiftData. Models are the persisted entry and the value types passed to the UI.

```
View  ->  ViewModel  ->  DataService / SentimentAnalysisService  ->  SwiftData / NLTagger
```

| Layer | Types | Responsibility |
| --- | --- | --- |
| App | `MoodScribeApp`, `RootView` | Creates the SwiftData container and hosts a tab for each main area |
| Model | `JournalEntry`, `SelectedMood`, `DayFactor`, `SentimentType` | Persisted reflection, chosen mood, factors, and writing tone |
| Service | `SentimentAnalysisService`, `DataService`, `SwiftDataService` | On-device scoring and CRUD |
| View model | `EntryComposerViewModel`, `EntryDetailViewModel`, `HistoryViewModel`, `JournalInsights` | Draft validation, save-time analysis, filters, and period summaries |
| View | Home, Composer, Reflection, Calendar, Trends, Settings, `SentimentGaugeView`, `moodCardStyle()` | Layout, motion, gestures, Dynamic Type |

`JournalEntry` stores `id`, `text`, `date`, `updatedAt`, the optional chosen mood, factors, and, when analysis ran, `sentimentScore`, `sentimentLabel`, `keywords`, and `didAnalyze`. New fields default so older entries remain readable. Screens use `JournalEntrySnapshot` instead of holding the SwiftData object.

Each tab has its own `NavigationStack`. Routes are `.composer`, `.reflection(id)`, and `.day(date)`. Saving a new reflection replaces the composer with that reflection.

### Sentiment analysis

`SentimentAnalysisService` does three things with `NaturalLanguage`:

1. `NLLanguageRecognizer` picks the dominant language and `NLTagger.setLanguage` applies it.
2. `NLTagger` with the `.sentimentScore` scheme walks sentences (then paragraphs if needed) and returns a length-weighted average clamped to -1.0...+1.0.
3. A second tagger uses `.lemma` and `.lexicalClass` to collect adjectives, nouns, and verbs, boosts a fixed emotion lexicon, drops stop words, and keeps at most six keywords.

Classification is explicit:

- score > 0.1 is Positive
- score < -0.1 is Negative
- otherwise Neutral

The color aura and radial gauge appear on the reflection screen after a save. They use those three anchors so the tone can sit between categories. Scoring runs when the entry is saved, on the device, so the stored number matches the text that was committed.

CloudKit is turned off. The store stays on the device. UI tests launch with `-ui-testing`, which opens an in-memory store so a previous run cannot leak entries into the next one.

### Accessibility and appearance

Colors use semantic system backgrounds (`Color(uiColor: .systemGroupedBackground)` and similar) plus a light and dark accent in the asset catalog. Sentiment tints have separate light and dark RGB anchors. Text uses Dynamic Type styles (`body`, `title`, `caption`) and the gauge diameter uses `@ScaledMetric`. Controls keep a minimum height of about 44 points. The calendar exposes an adjustable VoiceOver action for changing month. The reflection gauge describes the sentiment score and writing tone.

## Project layout

```
MoodScribe/
├── MoodScribe.xcodeproj
├── MoodScribe/
│   ├── App/MoodScribeApp.swift
│   ├── Models/
│   ├── Services/
│   ├── ViewModels/
│   ├── Views/
│   │   ├── Home/HomeView.swift
│   │   ├── Composer/ComposerView.swift
│   │   ├── Detail/EntryDetailView.swift
│   │   ├── Calendar/CalendarJournalView.swift
│   │   ├── Trends/TrendsView.swift
│   │   ├── Settings/SettingsView.swift
│   │   └── Components/
│   │       ├── SentimentGaugeView.swift
│   │       ├── SelectionChips.swift
│   │       └── Modifiers/MoodCardModifier.swift
│   ├── Support/AccessibilityID.swift
│   └── Resources/Assets.xcassets
├── MoodScribeTests/
│   ├── SentimentServiceTests.swift
│   └── ViewModelTests.swift
├── MoodScribeUITests/MoodScribeUITests.swift
├── .gitignore
└── README.md
```

## Requirements

- A Mac with Xcode 15.4 or newer. Xcode 16 is the version this project was prepared for.
- An iOS 17 or newer simulator. iPhone and iPad are both supported.
- No third-party packages. Natural Language and SwiftData ship with the iOS SDK.
- Windows can hold the Git repository, but it cannot compile or run this iOS app. Clone it on the Mac and open it in Xcode.

## Open, build, and run on a Mac

1. Clone the repository (see Git commands below) and `cd` into `MoodScribe`.
2. Open the project:
   ```bash
   open MoodScribe.xcodeproj
   ```
   Or double-click `MoodScribe.xcodeproj` in Finder. Open the `.xcodeproj`, not a loose folder of Swift files.
3. Wait for Xcode to finish indexing.
4. In the toolbar scheme menu, select the **MoodScribe** scheme.
5. Select an iOS 17+ simulator, for example iPhone 16.
6. Simulator builds are set to sign locally without a development team. To run on a physical iPhone, open the MoodScribe target, go to **Signing & Capabilities**, choose your Team, and let Xcode manage signing.
7. Press **Cmd + R** to build and launch.

The first screen is Home. Tap **New Reflection**, write at least a few words, and tap **Save**. The reflection summary opens next. Calendar, Trends, and Settings are the other tabs.

### Dark Mode and Dynamic Type

With the app running under the debugger, click the Environment Overrides button in the debug bar (the toggles icon). Turn on **Appearance** to switch Dark and Light, and turn on **Dynamic Type** to slide text size. You can also use the Simulator menu **Features > Toggle Appearance**, or the Settings app on the simulator: **Accessibility > Display & Text Size > Larger Text**.

## Tests

The shared scheme includes both test targets, so **Cmd + U** runs unit tests and UI tests.

From the command line, with a simulator already named in Xcode:

```bash
xcodebuild test \
  -project MoodScribe.xcodeproj \
  -scheme MoodScribe \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```

Change `name=iPhone 16` to a simulator you have installed (`xcrun simctl list devices available`).

### Unit tests (`MoodScribeTests`)

`SentimentServiceTests` checks:

- empty text returns a zero, neutral result
- scores stay inside -1.0...+1.0
- a clearly warm paragraph scores above a clearly bleak one, and each label matches `SentimentType.classify`
- a factual sentence scores below clear praise
- keyword extraction keeps anxious, grateful, and calm, caps the list at six, and drops stop words
- classification boundaries at ±0.1
- tone wording describes the writing and never calls the score a mental-health measure
- a `measure` block over a long entry

`ViewModelTests` uses an in-memory `ModelContainer` and checks:

- blank drafts are rejected and nothing is inserted
- save writes the analyzed text and history reloads it
- edit replaces the text and stores a freshly computed score
- delete removes the row from history and from the store
- detail load and delete
- search by body, keyword, mood, factor, and sentiment name, plus the Positive / Neutral / Negative filter
- 7-day and 30-day averages ignore entries outside the window
- month paging and day filtering
- chosen mood and factors are stored separately from the journal text, including an empty mood
- automatic analysis can be turned off
- week and month summaries stay quiet when there is not enough data
- the 2,000-character cap and draft reset

### UI tests (`MoodScribeUITests`)

UI tests launch with `-ui-testing` so the store is memory-only.

- `testCreateReflectionAndOpenIt` starts on Home, writes a reflection, saves, and checks the reflection-screen score, tone, text, edit, and delete controls. The composer does not show the radial gauge.
- `testCalendarSearchFiltersAndEmptyDay` checks calendar search, sentiment filters, and the empty-day message.
- `testSettingsExplainPrivacyAndAnalysis` checks the analysis toggles and the on-device privacy note.

If a UI test fails on the text view, run it once in the iOS Simulator with a hardware keyboard enabled (**I/O > Keyboard > Connect Hardware Keyboard**) and confirm the MoodScribe scheme is the test scheme. Unit tests do not need the keyboard.

## Testing approach and performance

Business rules live in view models and services, so most of the suite does not boot a view. Sentiment tests call `NLTagger` for real. They assert ordering and range rather than a single hard-coded model output, because Apple's on-device score can shift slightly between OS versions. CRUD tests use SwiftData's in-memory configuration, which exercises the same `DataService` the app uses without touching the simulator's documents directory.

`NLTagger` runs when a reflection is saved, not on each keystroke. That keeps typing responsive and stores a score that matches the final text. `SentimentAnalysisService.analyzeOffMain` is available when a caller wants the same work off the main actor.

Other limits that keep the UI responsive:

- keyword extraction stops at six terms
- history filtering and averages run on the snapshots already loaded, not with a second query per keystroke
- list rows use stable entry IDs so insertions and deletions animate instead of rebuilding identity
- the SwiftData configuration sets `cloudKitDatabase: .none`, which avoids a CloudKit entitlement the app does not use

To profile, run the app with **Product > Profile** (Cmd + I) and choose Time Profiler. Save a long reflection and confirm `NLTagger` work is limited to that save. The unit-test `measure` block is the automated check that a long entry stays in a reasonable range on the machine that runs the tests.

Memory stays small because entries are text plus a few numbers. There is no image pipeline and no network call.

## Rubric map

| Requirement | Where it lives |
| --- | --- |
| Three screens on `NavigationStack` | Home, Calendar, Trends, and Settings tabs, plus the composer and reflection routes |
| Animation, transitions, gestures, adaptive layout | Reflection gauge trim and aura, list removal, factor drag, calendar drag, `horizontalSizeClass` |
| Custom component and `ViewModifier` | `SentimentGaugeView`, `.moodCardStyle()` / `MoodCardModifier` |
| Dark Mode and Dynamic Type | Semantic colors, light/dark sentiment palette, text styles, `@ScaledMetric` |
| Local persistence | SwiftData `JournalEntry` and `SwiftDataService` |
| Emerging framework | `NaturalLanguage` `NLTagger` `.sentimentScore`, lemmas, and `NLLanguageRecognizer` |
| MVVM | `Views` / `ViewModels` / `Services` / `Models` |
| Unit and UI tests | `MoodScribeTests`, `MoodScribeUITests` |
| GitHub-ready Xcode project | `MoodScribe.xcodeproj`, shared scheme, `.gitignore` |

## GitHub

The repository is [Vimashperera/MoodScribe](https://github.com/Vimashperera/MoodScribe), on branch `main`.

On a Mac:

```bash
git clone https://github.com/Vimashperera/MoodScribe.git
cd MoodScribe
open MoodScribe.xcodeproj
```

To publish later changes from this folder:

```powershell
cd "E:\SLIIT\MADD IOS APP\MoodScribe"
git push origin main
```

Do not commit `xcuserdata`, DerivedData, or `.env` files. They are listed in `.gitignore`.
