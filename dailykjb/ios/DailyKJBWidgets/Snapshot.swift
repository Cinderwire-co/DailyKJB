// What the app leaves for its widgets (lib/services/widget_sync.dart): the plan, the next day to read, the streak, and a
// week of verses for each day. Kept in the app group the app already shares with its Screen Time extensions. From it a
// widget works out any day of the coming week itself, so it turns over at midnight with no help from the app.
import Foundation

struct Snapshot: Codable {
  struct Reading: Codable {
    let day: Int
    let title: String
    let short: String
    let minutes: Int
  }
  struct Verse: Codable {
    let date: String
    let ref: String
    let text: String
  }

  let name: String
  let plan: String
  let start: String  // the plan's day 1, yyyy-MM-dd
  let total: Int
  let completed: Int
  let streak: Int
  let lastRead: String?  // yyyy-MM-dd
  let complete: Bool
  let next: Reading?
  let verses: [Verse]

  static let suite = "group.com.dailykjb.dailyKjb.shared"
  static let key = "widget_snapshot"

  static func load() -> Snapshot? {
    guard let s = UserDefaults(suiteName: suite)?.string(forKey: key), let d = s.data(using: .utf8) else { return nil }
    return try? JSONDecoder().decode(Snapshot.self, from: d)
  }

  func verse(on date: Date) -> Verse? {
    let k = dayKey(date)
    return verses.first { $0.date == k } ?? verses.last
  }

  /// The plan as it stands on a given day.
  func day(_ date: Date) -> Day {
    let k = dayKey(date)
    let read = lastRead == k
    let cal = Calendar(identifier: .gregorian)
    var calendarDay = 1
    if let s = Self.parse(start) {
      calendarDay = (cal.dateComponents([.day], from: cal.startOfDay(for: s), to: cal.startOfDay(for: date)).day ?? 0) + 1
      calendarDay = min(max(calendarDay, 1), max(total, 1))
    }
    // The streak holds through the day after the last reading
    var keeps = read
    if !keeps, let last = lastRead.flatMap(Self.parse),
       let gap = cal.dateComponents([.day], from: cal.startOfDay(for: last), to: cal.startOfDay(for: date)).day {
      keeps = gap <= 1
    }
    return Day(
      read: read, complete: complete, next: next, calendarDay: calendarDay,
      catchUp: !read && (next?.day ?? calendarDay) < calendarDay,
      streak: keeps ? streak : 0,
      share: total > 0 ? Double(completed) / Double(total) : 0,
      completed: completed, total: total, plan: plan)
  }

  static func parse(_ s: String) -> Date? {
    let f = DateFormatter()
    f.calendar = Calendar(identifier: .gregorian)
    f.locale = Locale(identifier: "en_US_POSIX")
    f.timeZone = .current
    f.dateFormat = "yyyy-MM-dd"
    return f.date(from: s)
  }
}

/// One day of the plan, as a widget shows it.
struct Day {
  let read: Bool  // today's reading is done
  let complete: Bool  // the whole plan is
  let next: Snapshot.Reading?  // the next day to read
  let calendarDay: Int
  let catchUp: Bool
  let streak: Int
  let share: Double
  let completed: Int
  let total: Int
  let plan: String
}

enum Sample {
  static let verse = Snapshot.Verse(
    date: dayKey(.now), ref: "Lamentations 3:22–23",
    text: "It is of the LORD's mercies that we are not consumed, because his compassions fail not. They are new every morning: great is thy faithfulness.")
  static let day = Day(
    read: false, complete: false,
    next: Snapshot.Reading(day: 41, title: "Leviticus 21–23; Psalm 41", short: "Lev. 21–23; Psa. 41", minutes: 15),
    calendarDay: 41, catchUp: false, streak: 23, share: 0.11, completed: 40, total: 365, plan: "Whole Bible")
}
