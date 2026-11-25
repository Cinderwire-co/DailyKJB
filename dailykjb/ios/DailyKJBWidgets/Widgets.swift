// Daily KJB on the home screen and lock screen: today's reading (read or not, the plan's progress, days in a row) and
// the verse for today. Both draw from what the app last left (Snapshot.swift), a day at a time for a week ahead, so they
// turn over just after midnight on their own; the app asks for them again whenever the plan changes. A tap opens the
// day's reading, or the verse in the Bible.
import SwiftUI
import WidgetKit

@main
struct DailyKJBWidgets: WidgetBundle {
  var body: some Widget {
    TodayWidget()
    VerseWidget()
  }
}

extension WidgetFamily {
  var size: Size {
    switch self {
    case .systemMedium: return .medium
    case .systemLarge, .systemExtraLarge: return .large
    case .accessoryRectangular: return .rectangular
    case .accessoryInline: return .inline
    case .accessoryCircular: return .circular
    default: return .small
    }
  }
}

struct Back: View {
  @Environment(\.colorScheme) private var scheme
  var body: some View { PaperBack(p: Palette.of(scheme)) }
}

func link(_ path: String) -> URL { URL(string: "dailykjb://\(path)")! }

func verseLink(_ v: Snapshot.Verse?) -> URL {
  guard let v, let ref = v.ref.addingPercentEncoding(withAllowedCharacters: .alphanumerics) else { return link("bible") }
  return link("verse?ref=\(ref)")
}

/// A day at a time for the coming week: now, then just after each midnight.
func days(_ count: Int = 7) -> [Date] {
  let cal = Calendar.current
  let today = cal.startOfDay(for: .now)
  return [.now] + (1..<count).compactMap { cal.date(byAdding: .day, value: $0, to: today)?.addingTimeInterval(60) }
}

// MARK: Today's reading

struct TodayEntry: TimelineEntry {
  let date: Date
  let day: Day?
}

struct TodayProvider: TimelineProvider {
  func placeholder(in context: Context) -> TodayEntry { TodayEntry(date: .now, day: Sample.day) }
  func getSnapshot(in context: Context, completion: @escaping (TodayEntry) -> Void) {
    let s = Snapshot.load()
    completion(TodayEntry(date: .now, day: s?.day(.now) ?? (context.isPreview ? Sample.day : nil)))
  }
  func getTimeline(in context: Context, completion: @escaping (Timeline<TodayEntry>) -> Void) {
    let s = Snapshot.load()
    let entries = days().map { TodayEntry(date: $0, day: s?.day($0)) }
    completion(Timeline(entries: entries, policy: .atEnd))
  }
}

struct TodayWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: "DailyKJBToday", provider: TodayProvider()) { e in
      TodayEntryView(e: e).containerBackground(for: .widget) { Back() }
        .widgetURL(e.day?.complete == true ? link("today") : link("read"))
    }
    .configurationDisplayName("Today's reading")
    .description("The day's chapters, whether they're read, and how far through the plan you are.")
    .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular, .accessoryInline])
  }
}

struct TodayEntryView: View {
  let e: TodayEntry
  @Environment(\.widgetFamily) private var family
  @Environment(\.colorScheme) private var scheme
  var body: some View { TodayView(day: e.day, size: family.size, p: Palette.of(scheme)) }
}

// MARK: The verse for today

struct VerseEntry: TimelineEntry {
  let date: Date
  let verse: Snapshot.Verse?
}

struct VerseProvider: TimelineProvider {
  func placeholder(in context: Context) -> VerseEntry { VerseEntry(date: .now, verse: Sample.verse) }
  func getSnapshot(in context: Context, completion: @escaping (VerseEntry) -> Void) {
    completion(VerseEntry(date: .now, verse: Snapshot.load()?.verse(on: .now) ?? Sample.verse))
  }
  func getTimeline(in context: Context, completion: @escaping (Timeline<VerseEntry>) -> Void) {
    let s = Snapshot.load()
    let entries = days().map { VerseEntry(date: $0, verse: s?.verse(on: $0) ?? Sample.verse) }
    completion(Timeline(entries: entries, policy: .atEnd))
  }
}

struct VerseWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: "DailyKJBVerse", provider: VerseProvider()) { e in
      VerseEntryView(e: e).containerBackground(for: .widget) { Back() }.widgetURL(verseLink(e.verse))
    }
    .configurationDisplayName("The verse for today")
    .description("A verse from the King James Bible, new each morning.")
    .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryRectangular, .accessoryInline])
  }
}

struct VerseEntryView: View {
  let e: VerseEntry
  @Environment(\.widgetFamily) private var family
  @Environment(\.colorScheme) private var scheme
  var body: some View { VerseView(verse: e.verse, size: family.size, p: Palette.of(scheme)) }
}
