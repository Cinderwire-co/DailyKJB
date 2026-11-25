// What each widget draws, at each size. The lock screen's sizes take the phone's own tint, so they're drawn in
// primary and secondary only.
import SwiftUI

// MARK: Today's reading

struct TodayView: View {
  let day: Day?
  let size: Size
  let p: Palette

  var body: some View {
    if let d = day {
      switch size {
      case .circular: circular(d)
      case .rectangular: rectangular(d)
      case .inline: inline(d)
      case .medium, .large: medium(d)
      case .small: small(d)
      }
    } else {
      Setup(p: p, size: size)
    }
  }

  private var percent: String { "\(Int(((day?.share ?? 0) * 100).rounded()))%" }

  private func label(_ d: Day) -> (String, Color) {
    if d.complete { return ("Finished", p.gold) }
    if d.read { return ("Today is read", p.success) }
    if d.catchUp { return ("Catching up", p.rubric) }
    return ("Today's reading", p.accent)
  }

  private func small(_ d: Day) -> some View {
    let (l, c) = label(d)
    return VStack(alignment: .leading, spacing: 0) {
      HStack(spacing: 4) {
        if d.read { Image(systemName: "checkmark.seal.fill").font(.system(size: 10)).foregroundStyle(c) }
        Caps(text: l, color: c, size: 8.5)
      }
      Spacer(minLength: 6)
      if d.complete {
        Text("The plan is finished").font(Lettering.caps(15)).foregroundStyle(p.strong).lineLimit(3)
      } else if let n = d.next {
        if d.read { Text("Next").font(Lettering.italic(13)).foregroundStyle(p.faded) }
        Text(n.short).font(Lettering.caps(16)).foregroundStyle(p.strong)
          .lineLimit(3).minimumScaleFactor(0.7).fixedSize(horizontal: false, vertical: true)
        Text("Day \(n.day) · \(n.minutes) min").font(Lettering.serif(12.5)).foregroundStyle(p.faded).padding(.top, 2)
      }
      Spacer(minLength: 6)
      HStack(spacing: 6) {
        GeometryReader { g in
          ZStack(alignment: .leading) {
            Capsule().fill(p.deep)
            Capsule().fill(p.accent).frame(width: max(4, g.size.width * min(1, d.share)))
          }
        }
        .frame(height: 4)
        Text(percent).font(Lettering.serif(11.5)).foregroundStyle(p.faded)
        if d.streak > 0 {
          HStack(spacing: 1) {
            Image(systemName: "flame.fill").font(.system(size: 9))
            Text("\(d.streak)").font(Lettering.strong(11.5))
          }
          .foregroundStyle(p.accent)
        }
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
  }

  private func medium(_ d: Day) -> some View {
    let (l, c) = label(d)
    return HStack(spacing: 14) {
      VStack(alignment: .leading, spacing: 0) {
        HStack(spacing: 4) {
          if d.read { Image(systemName: "checkmark.seal.fill").font(.system(size: 11)).foregroundStyle(c) }
          Caps(text: l, color: c, size: 9)
        }
        Spacer(minLength: 4)
        if d.complete {
          Text("The plan is finished").font(Lettering.caps(19)).foregroundStyle(p.strong)
          Text("Every day of \(d.plan).").font(Lettering.italic(14)).foregroundStyle(p.faded)
        } else if let n = d.next {
          if d.read { Text("Next, day \(n.day)").font(Lettering.italic(14)).foregroundStyle(p.faded) }
          Text(n.title).font(Lettering.caps(19)).foregroundStyle(p.strong)
            .lineLimit(2).minimumScaleFactor(0.7).fixedSize(horizontal: false, vertical: true)
          HStack(spacing: 5) {
            Image(systemName: "clock").font(.system(size: 10))
            Text(d.read ? "\(n.minutes) min" : "Day \(n.day) of \(d.total) · about \(n.minutes) min")
              .font(Lettering.serif(13.5))
          }
          .foregroundStyle(p.faded)
          .padding(.top, 3)
        }
        Spacer(minLength: 4)
        if d.streak > 0 {
          HStack(spacing: 3) {
            Image(systemName: "flame.fill").font(.system(size: 10))
            Text("\(d.streak) \(d.streak == 1 ? "day" : "days") in a row").font(Lettering.strong(13))
          }
          .foregroundStyle(p.accent)
        } else {
          Text(d.plan).font(Lettering.serif(13)).foregroundStyle(p.faded)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      Ring(value: d.share, p: p, line: 6) {
        VStack(spacing: -1) {
          Text(percent).font(Lettering.caps(15)).foregroundStyle(p.strong)
          Text("\(d.completed) of \(d.total)").font(Lettering.serif(10)).foregroundStyle(p.faded)
        }
      }
      .frame(width: 78, height: 78)
    }
  }

  private func rectangular(_ d: Day) -> some View {
    VStack(alignment: .leading, spacing: 1) {
      HStack(spacing: 3) {
        Image(systemName: d.read ? "checkmark.seal.fill" : "book.fill").font(.system(size: 10))
        Text(d.complete ? "FINISHED" : d.read ? "TODAY IS READ" : "DAY \(d.next?.day ?? d.calendarDay)")
          .font(.system(size: 11, weight: .semibold)).tracking(0.6)
      }
      if let n = d.next, !d.complete {
        Text(d.read ? "Next: \(n.short)" : n.short).font(.system(size: 14, weight: .semibold)).lineLimit(2)
          .minimumScaleFactor(0.8)
      }
      Text(d.streak > 0 ? "\(Int((d.share * 100).rounded()))% · \(d.streak) in a row" : "\(Int((d.share * 100).rounded()))% of the plan")
        .font(.system(size: 12)).foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private func circular(_ d: Day) -> some View {
    Gauge(value: min(1, d.share)) {
      Image(systemName: "book.closed.fill")
    } currentValueLabel: {
      if d.read { Image(systemName: "checkmark") } else { Text(percent).font(.system(size: 12, weight: .semibold)) }
    }
    .gaugeStyle(.accessoryCircularCapacity)
  }

  private func inline(_ d: Day) -> Text {
    if d.complete { return Text("\(Image(systemName: "rosette")) Plan finished") }
    if d.read { return Text("\(Image(systemName: "checkmark.seal.fill")) Today is read") }
    return Text("\(Image(systemName: "book.fill")) \(d.next?.short ?? "Today's reading")")
  }
}

// MARK: The verse for today

struct VerseView: View {
  let verse: Snapshot.Verse?
  let size: Size
  let p: Palette

  var body: some View {
    if let v = verse {
      switch size {
      case .rectangular:
        VStack(alignment: .leading, spacing: 1) {
          Text(v.text).font(.system(size: 13, design: .serif)).lineLimit(3).minimumScaleFactor(0.8)
          Text(v.ref).font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      case .inline:
        Text("\(Image(systemName: "book.closed")) \(v.ref)")
      case .circular:
        Image(systemName: "book.closed.fill")
      case .small: card(v, text: 14.5, quote: 30, ornament: false)
      case .medium: card(v, text: 16.5, quote: 30, ornament: false)
      case .large: card(v, text: 22, quote: 46, ornament: true)
      }
    } else {
      Setup(p: p, size: size)
    }
  }

  private func card(_ v: Snapshot.Verse, text: CGFloat, quote: CGFloat, ornament: Bool) -> some View {
    VStack(spacing: 0) {
      if ornament {
        Caps(text: "The verse for today", color: p.faded, size: 9.5)
        Spacer(minLength: 8)
      }
      Text("\u{201C}").font(Lettering.serif(quote)).foregroundStyle(p.accent).frame(height: quote * 0.5)
      Text(v.text)
        .font(Lettering.italic(text))
        .foregroundStyle(p.strong)
        .multilineTextAlignment(.center)
        .lineSpacing(1)
        .minimumScaleFactor(0.55)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      if ornament {
        Ornament(color: p.gold, width: 90).padding(.vertical, 8)
      } else {
        Spacer(minLength: 4).frame(maxHeight: 6)
      }
      Caps(text: v.ref, color: p.accent, size: size == .small ? 8.5 : 10)
      if ornament {
        Caps(text: "Daily KJB", color: p.faded.opacity(0.7), size: 8).padding(.top, 10)
      }
    }
  }
}

// Before the app has been opened and set up on this phone
struct Setup: View {
  let p: Palette
  let size: Size
  var body: some View {
    switch size {
    case .inline: Text("Open Daily KJB")
    case .circular: Image(systemName: "book.closed.fill")
    case .rectangular:
      VStack(alignment: .leading) {
        Text("DAILY KJB").font(.system(size: 11, weight: .semibold))
        Text("Open the app to begin").font(.system(size: 13))
      }
    default:
      VStack(alignment: .leading, spacing: 6) {
        Caps(text: "Daily KJB", color: p.accent)
        Spacer(minLength: 0)
        Text("Open Daily KJB and choose a reading plan to see it here.")
          .font(Lettering.serif(14)).foregroundStyle(p.strong)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
  }
}
