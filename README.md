# MoodScribe

MoodScribe is a native iOS journal for daily mental-health check-ins. You write in your own words, and the app scores the emotional tone on the device with Apple's Natural Language framework, then keeps the entry in a local SwiftData store.

It is built for adults and university students who want a private place to notice mood patterns. It is not a medical device and it does not diagnose, treat, or replace professional care.

The app is the SE4041 (Mobile Application Design and Development) Part A submission. The interface is SwiftUI, the language is Swift 5, and the deployment target is iOS 17.

## What you can do

1. **Journal composer.** Write a multi-line entry, watch a live word and character count, and see a sentiment aura and radial gauge move from warm red through amber to teal as the text changes.
2. **Insights.** Open an entry to read the full text, the polarity score from -1.0 to +1.0, a mood-index percentage, the Positive / Neutral / Negative class, and the emotional keywords extracted from the text. Edit or delete the entry from this screen.
3. **History.** Browse a month calendar and a filterable list. Search by word, keyword, or sentiment name. Switch the summary card between a 7-day and a 30-day average. Swipe a row and confirm before it is deleted.

Quick mood tags can be tapped or dragged vertically to toggle, or pressed and held to insert a phrase. Press and hold the gauge, or drag it downward, to reset a draft. Drag the mood-tag caption to the left to clear selected tags. Drag the calendar sideways, or use the chevrons, to change month.

On a regular-width iPad layout the composer and the history screen place the writing surface and the insight panels side by side. On iPhone they stack.

## Architecture

MoodScribe uses MVVM. Views render state and forward actions. View models own validation, filtering, and save rules. Services own Natural Language and SwiftData. Models are the persisted entry and the value types passed to the UI.

```
View  ->  ViewModel  ->  DataService / SentimentAnalysisService  ->  SwiftData / NLTagger
```

| Layer | Types | Responsibility |
| --- | --- | --- |
| App | `MoodScribeApp`, `RootView` | Creates the SwiftData container and hosts a `NavigationStack` |
| Model | `JournalEntry`, `SentimentType`, `JournalEntrySnapshot` | Persisted record and the value snapshot views display |
| Service | `SentimentAnalysisService`, `DataService`, `SwiftDataService` | On-device scoring and CRUD |
| View model | `EntryComposerViewModel`, `EntryDetailViewModel`, `HistoryViewModel` | Draft validation, debounced analysis, filters, trends |
| View | Composer, Insights, History, `SentimentGaugeView`, `moodCardStyle()` | Layout, motion, gestures, Dynamic Type |

`JournalEntry` is a SwiftData `@Model` with `id`, `text`, `date`, `updatedAt`, `sentimentScore`, `sentimentLabel`, and `keywords`. Screens do not hold the model object directly. View models map it to `JournalEntrySnapshot` so lists and detail refresh from plain values.

Navigation uses one `NavigationStack` and a `Hashable` `AppRoute`:

- History is the root.
- New Entry and Edit push `ComposerView`.
- A row pushes `EntryDetailView`.

Routes are `.composer(.create)`, `.composer(.edit(id))`, and `.detail(id)`.

### Sentiment analysis

`SentimentAnalysisService` does three things with `NaturalLanguage`:

1. `NLLanguageRecognizer` picks the dominant language and `NLTagger.setLanguage` applies it.
2. `NLTagger` with the `.sentimentScore` scheme walks sentences (then paragraphs if needed) and returns a length-weighted average clamped to -1.0...+1.0.
3. A second tagger uses `.lemma` and `.lexicalClass` to collect adjectives, nouns, and verbs, boosts a fixed emotion lexicon, drops stop words, and keeps at most six keywords.

Classification is explicit:

- score > 0.1 is Positive
- score < -0.1 is Negative
- otherwise Neutral

The color aura interpolates between those three anchors so the gauge can move while the user is still inside the neutral band. Typing is debounced by 160 ms and scored off the main actor. Save scores synchronously so the stored number matches the text that was committed.

CloudKit is turned off. The store stays on the device. UI tests launch with `-ui-testing`, which opens an in-memory store so a previous run cannot leak entries into the next one.

### Accessibility and appearance

Colors use semantic system backgrounds (`Color(uiColor: .systemGroupedBackground)` and similar) plus a light and dark accent in the asset catalog. Sentiment tints have separate light and dark RGB anchors. Text uses Dynamic Type styles (`body`, `title`, `caption`) and the gauge diameter uses `@ScaledMetric`. Controls keep a minimum height of about 44 points. The calendar exposes an adjustable VoiceOver action for changing month, and the gauge exposes a Reset draft action.

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
│   │   ├── Composer/ComposerView.swift
│   │   ├── Detail/EntryDetailView.swift
│   │   ├── History/HistoryListView.swift
│   │   └── Components/
│   │       ├── SentimentGaugeView.swift
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

The first screen is the history list. Tap **New Entry**, write at least a few words, and tap **Save**. The row appears on the history screen. Tap it to open Insights.

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
- mood-index endpoints at 0%, 50%, and 100%
- a `measure` block over a long entry

`ViewModelTests` uses an in-memory `ModelContainer` and checks:

- blank drafts are rejected and nothing is inserted
- save writes the analyzed text and history reloads it
- edit replaces the text and stores a freshly computed score
- delete removes the row from history and from the store
- detail load and delete
- search by body, keyword, and sentiment name, plus the Positive / Neutral / Negative filter
- 7-day and 30-day averages ignore entries outside the window
- month paging and day filtering
- selected mood tags are appended to the saved text
- the 2,000-character cap and draft reset

### UI tests (`MoodScribeUITests`)

UI tests launch with `-ui-testing` so the store is memory-only.

- `testCreateEntryAndVisitAllThreeScreens` opens History, pushes the composer, types an entry, saves, opens Insights, checks the score, text, edit, and delete controls, then returns to History.
- `testSearchAndSentimentFilters` checks the search field and the sentiment filter chips.

If a UI test fails on the text view, run it once in the iOS Simulator with a hardware keyboard enabled (**I/O > Keyboard > Connect Hardware Keyboard**) and confirm the MoodScribe scheme is the test scheme. Unit tests do not need the keyboard.

## Testing approach and performance

Business rules live in view models and services, so most of the suite does not boot a view. Sentiment tests call `NLTagger` for real. They assert ordering and range rather than a single hard-coded model output, because Apple's on-device score can shift slightly between OS versions. CRUD tests use SwiftData's in-memory configuration, which exercises the same `DataService` the app uses without touching the simulator's documents directory.

Live typing does not run `NLTagger` on every keystroke on the main thread. `EntryComposerViewModel` waits 160 ms, cancels the previous task, and scores the snapshot with `Task.detached`. A later keystroke whose text no longer matches that snapshot is ignored. Save still analyzes on the calling actor so the database cannot store a stale debounce result.

Other limits that keep the UI responsive:

- keyword extraction stops at six terms
- history filtering and averages run on the snapshots already loaded, not with a second query per keystroke
- list rows use stable entry IDs so insertions and deletions animate instead of rebuilding identity
- the SwiftData configuration sets `cloudKitDatabase: .none`, which avoids a CloudKit entitlement the app does not use

To profile, run the app with **Product > Profile** (Cmd + I) and choose Time Profiler. Type quickly in the composer and confirm `NLTagger` work sits off the main thread after the debounce. The unit-test `measure` block is the automated check that a long entry stays in a reasonable range on the machine that runs the tests.

Memory stays small because entries are text plus a few numbers. There is no image pipeline and no network call.

## Rubric map

| Requirement | Where it lives |
| --- | --- |
| Three screens on `NavigationStack` | `RootView`, History, Composer, Insights |
| Animation, transitions, gestures, adaptive layout | Gauge trim and aura, list removal, tag drag, gauge long-press, calendar drag, `horizontalSizeClass` |
| Custom component and `ViewModifier` | `SentimentGaugeView`, `.moodCardStyle()` / `MoodCardModifier` |
| Dark Mode and Dynamic Type | Semantic colors, light/dark sentiment palette, text styles, `@ScaledMetric` |
| Local persistence | SwiftData `JournalEntry` and `SwiftDataService` |
| Emerging framework | `NaturalLanguage` `NLTagger` `.sentimentScore`, lemmas, and `NLLanguageRecognizer` |
| MVVM | `Views` / `ViewModels` / `Services` / `Models` |
| Unit and UI tests | `MoodScribeTests`, `MoodScribeUITests` |
| GitHub-ready Xcode project | `MoodScribe.xcodeproj`, shared scheme, `.gitignore` |

## Git: create `main` and push to GitHub

The folder on this machine already has a local Git repository. These commands rename the branch to `main`, make one commit per layer, and push. Run them in PowerShell from the project root. The GitHub repository is [Vimashperera/MoodScribe](https://github.com/Vimashperera/MoodScribe). Create it empty (no README and no license) if it does not exist yet, so the histories do not diverge.

```powershell
cd "E:\SLIIT\MADD IOS APP\MoodScribe"
git symbolic-ref HEAD refs/heads/main

git add .gitignore .gitattributes README.md MoodScribe.xcodeproj
git commit -m "Add the Xcode project, gitignore, and setup guide."

git add MoodScribe/App MoodScribe/Models MoodScribe/Services MoodScribe/Support
git commit -m "Add SwiftData models and on-device sentiment analysis."

git add MoodScribe/ViewModels
git commit -m "Add composer, detail, and history view models."

git add MoodScribe/Views MoodScribe/Resources
git commit -m "Add the three NavigationStack screens and sentiment components."

git add MoodScribeTests MoodScribeUITests
git commit -m "Add unit and UI tests for sentiment, persistence, and navigation."

git remote add origin https://github.com/Vimashperera/MoodScribe.git
git push -u origin main
```

If `origin` already exists, skip `git remote add` and run `git push -u origin main`.

On a Mac, after the push:

```bash
git clone https://github.com/Vimashperera/MoodScribe.git
cd MoodScribe
open MoodScribe.xcodeproj
```

A brand-new folder that is not already a repository would start with `git init` and then the same `git symbolic-ref HEAD refs/heads/main` line before the first commit.

Do not commit `xcuserdata`, DerivedData, or `.env` files. They are listed in `.gitignore`.
