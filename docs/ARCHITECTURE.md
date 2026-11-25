# Architecture

Daily KJB is a Flutter app for iOS and iPadOS (with an Android build) and a native Swift layer for Screen Time and Apple Intelligence. State lives in `ChangeNotifier`s (`AppProvider`, `Marks`, `AiService`); storage is `shared_preferences`. There is no server: everything the app shows is in the app.

## The Bible and the study data

```
assets/bible/kjb.tsv.gz ──► Kjb (lib/bible/kjb.dart)     the text, books, references, plan passages
assets/study/
  strongs.tsv.gz        ──► StudyData.strongs()           Strong's Hebrew and Greek, loaded once
  words/<book>.tsv.gz   ──► StudyData.verse()             each verse's words and their Strong's numbers
  xrefs/<book>.tsv.gz   ──┘                               the best 20 cross references a verse
  webster/<a-z>.tsv.gz  ──► StudyData.webster()           Webster's 1828, by first letter
```

- **`Kjb.load()`** decompresses the whole Bible in an isolate on start (about 4 MB of text) and keeps it in memory, so any chapter is there the moment it's asked for.
- **`Kjb.spans()`** turns a plan's passage into the chapters it covers, any in part: `Gen 1-3`, `Mat 2:19–3:17`, `2 Co 13:11–Gal 1:10`, `Oba`.
- **`StudyData.align()`** lines each Strong's word up with the words of the verse as printed (they come in order, nearly always together), and picks the word to look up in Webster's: the plainer word beside a little one ("the" in "the heaven" looks up heaven).
- **`StudyData.webster()`** tries the word as spelled, then the forms the King James makes from a plainer word (*goeth*, *saith*, *loved*, *sinned*). A form with only a line of its own brings the plainer word's entry with it.

## Reading plans

A plan is a CSV of rows (`"2026-01-01","Gen 1-3"`). `BibleService.loadUnits()` turns the rows into **units**, one per chapter or part of one, each remembering its row. `BibleService.spread()` shares the units over the length the reader chose:

- At the plan's own pace or faster (90, 180, 365 days), a day is whole rows, as the plan's authors grouped them.
- Slower (730 days), the units are shared out evenly, so no day is ever empty.

Progress is kept by unit (`UserData.completedUnits`), so changing a plan's length keeps what's been read. Saves from version 1, which kept rows, are moved over on first open.

Days are counted by calendar date in UTC (`AppProvider._daysBetween`), so neither the time a plan was started nor a change of clocks moves a day.

## The reader

`ChapterView` (`lib/screens/reader.dart`) draws one chapter, or the part a plan gives: verse numbers in the margin, a red initial, highlights on the words only, notes under the chapter. The Bible tab and the day's reading both put chapters in a `PageView`, one to a page, with haptics on each turn. `VerseActions` is the shared behaviour behind the floating panel: highlight, note, copy, share, study.

## Apple Intelligence

```
AiService (Dart) ──MethodChannel com.dailykjb/ai──► AIChannel.swift ──► FoundationModels (on device)
   availability                                        SystemLanguageModel.default.availability
   explainVerse  ──── verse, context, Strong's, xrefs ─► guided generation: VerseNotes
   wordMeaning   ──── word, verse, Strong's, Webster's ► plain text
   quiz          ──── the day's chapters ──────────────► guided generation: Quiz
```

- Every request carries the same instructions (King James only, no other translations, Strong's only explains the English, nothing invented), in `AIChannel.swift`.
- Results are kept in `shared_preferences`, so a verse's notes are written once.
- References in the notes are checked with `Kjb.verse()`; any that isn't a real verse is dropped.
- `FoundationModels` is weak linked (Runner's `OTHER_LDFLAGS`), so the app opens on iOS 16 to 25. Where the model isn't available the features are hidden, or a line says how to turn Apple Intelligence on.

## Focus Mode (Screen Time)

| Target | File | Job |
| --- | --- | --- |
| Runner | `ScreenTimeManager.swift` | Authorization, the saved selection, shields, the daily `DeviceActivity` schedule |
| Runner | `AppBlockingChannel.swift` | The `com.dailykjb/app_blocking` channel and the app picker |
| DeviceActivityMonitor | `DeviceActivityMonitorExtension.swift` | At each midnight, raises the shields unless the day is read |
| ShieldConfiguration | `ShieldConfigurationExtension.swift` | The shield's parchment look and words |
| ShieldAction | `ShieldActionExtension.swift` | "Read now" opens the app at today's reading (`.openParentalControlsApp`, iOS 26.5+; before that, a notification that opens it) |

The app and extensions share an app group (`group.com.dailykjb.dailyKjb.shared`) for the selection and the day's state, and a named `ManagedSettingsStore` (`dailykjb`). `blocking_enabled` changes only when the reader turns Focus Mode on or off; reading the day clears the shields without touching it. On each open the app calls `enableBlocking` (idempotent), then `markReadingComplete` if today is read.

"Read now" leaves `shield_read_now` (a timestamp) in the app group before it opens the app; `Links.fromShield()` takes it (once, within ten minutes) on launch or return and opens the day's reading.

## Widgets

```
AppProvider ──► WidgetSync (lib/services/widget_sync.dart) ──channel com.dailykjb/home──► HomeScreenBridge.swift
                  the plan, the next day to read, the streak,                               app group defaults
                  a week of verses (VerseOfDayService.week)                                 "widget_snapshot"
                                                                                             WidgetCenter reload
DailyKJBWidgets (WidgetKit) ◄── Snapshot.swift reads it, works out each day of the week ahead
```

- **Today's reading** (small, medium, lock screen circular, rectangular and inline) and **The verse for today** (small, medium, large, lock screen rectangular and inline).
- Each timeline holds a week: now, then just after each midnight. Whether a day is read, whether it's a catch-up day, and whether the streak still holds are worked out per day from the snapshot, so the widgets turn over with no help from the app. The app sends a fresh snapshot (debounced) whenever it saves, opens or comes back.
- The verse of the day is chosen a week ahead and kept (`verse_of_day_plan`), so the app and the widget always agree.
- A tap opens `dailykjb://read` (the next day's reading) or `dailykjb://verse?ref=…` (the Bible at that verse). `HomeScreenBridge` is a plugin registered as a Flutter scene delegate, so it sees the link whether the app was running or not; `FlutterDeepLinkingEnabled` is off so Flutter doesn't also try to route it. `HomeScreen` follows it (`Links` in `widget_sync.dart`).
- The views (`Views.swift`, `Look.swift`) don't use WidgetKit, so `tools/widget_shots.swift` draws them on the Mac.

## App lifecycle

The app uses the UIScene lifecycle (`SceneDelegate.swift`, `UIApplicationSceneManifest`), which iOS 27 requires. Plugins and the two channels are registered in `didInitializeImplicitFlutterEngine`.
