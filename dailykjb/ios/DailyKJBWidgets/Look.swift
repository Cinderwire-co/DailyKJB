// The app's look on the home screen (lib/ui/theme.dart): parchment by day, lamplight by night, as the phone is set;
// Cinzel capitals and EB Garamond; burnt orange for what matters, rubric red for numbers. Nothing here is WidgetKit's,
// so the same views draw on a Mac to be looked at (tools/widget_shots.swift).
import SwiftUI

struct Palette {
  let isDark: Bool
  let page, leaf, deep, rule, ink, strong, faded, accent, rubric, gold, success, grain: Color
  static func of(_ scheme: ColorScheme) -> Palette { scheme == .dark ? lamplight : parchment }

  static let parchment = Palette(
    isDark: false, page: Color(hex: 0xF3E9D7), leaf: Color(hex: 0xFAF4E8), deep: Color(hex: 0xEADCC3),
    rule: Color(hex: 0xD9C6A6), ink: Color(hex: 0x3B2E24), strong: Color(hex: 0x2A1E15), faded: Color(hex: 0x7C6852),
    accent: Color(hex: 0xC0632B), rubric: Color(hex: 0xA2391F), gold: Color(hex: 0xB0832C), success: Color(hex: 0x5E8A4E),
    grain: Color(hex: 0x6E4B2A))
  static let lamplight = Palette(
    isDark: true, page: Color(hex: 0x1C1611), leaf: Color(hex: 0x261E17), deep: Color(hex: 0x30261D),
    rule: Color(hex: 0x433628), ink: Color(hex: 0xE7DBC9), strong: Color(hex: 0xF5ECDD), faded: Color(hex: 0xA6957F),
    accent: Color(hex: 0xE79B5D), rubric: Color(hex: 0xE2805A), gold: Color(hex: 0xD8B06A), success: Color(hex: 0x8DBA78),
    grain: Color(hex: 0xFFE9C8))
}

extension Color {
  init(hex: UInt32, alpha: Double = 1) {
    self.init(.sRGB, red: Double(hex >> 16 & 0xFF) / 255, green: Double(hex >> 8 & 0xFF) / 255,
              blue: Double(hex & 0xFF) / 255, opacity: alpha)
  }
}

// The app's two faces, carried in the extension (Info.plist, UIAppFonts)
enum Lettering {
  static func caps(_ size: CGFloat) -> Font { .custom("Cinzel-SemiBold", size: size) }
  static func serif(_ size: CGFloat) -> Font { .custom("EBGaramond-Regular", size: size) }
  static func italic(_ size: CGFloat) -> Font { .custom("EBGaramond-Italic", size: size) }
  static func strong(_ size: CGFloat) -> Font { .custom("EBGaramond-SemiBold", size: size) }
}

// Small spaced capitals over a section, as in the app
struct Caps: View {
  let text: String
  var color: Color
  var size: CGFloat = 9.5
  var body: some View {
    Text(text.uppercased()).font(Lettering.caps(size)).tracking(size * 0.18).foregroundStyle(color).lineLimit(1)
  }
}

// The page behind every widget: parchment and its grain, a little darker at the edges
struct PaperBack: View {
  let p: Palette
  var body: some View {
    ZStack {
      p.page
      Image("Grain").resizable(resizingMode: .tile).renderingMode(.template)
        .foregroundStyle(p.grain.opacity(p.isDark ? 0.16 : 0.32))
      RadialGradient(colors: [.clear, (p.isDark ? Color.black : Color(hex: 0x8A5A2B)).opacity(p.isDark ? 0.28 : 0.10)],
                     center: .center, startRadius: 40, endRadius: 260)
    }
  }
}

// A printer's ornament: a rule, a lozenge, a rule
struct Ornament: View {
  let color: Color
  var width: CGFloat = 70
  var body: some View {
    HStack(spacing: 5) {
      Rectangle().fill(color.opacity(0.75)).frame(height: 0.8)
      Circle().fill(color).frame(width: 2.6, height: 2.6)
      Rectangle().fill(color).frame(width: 6, height: 6).rotationEffect(.degrees(45))
      Circle().fill(color).frame(width: 2.6, height: 2.6)
      Rectangle().fill(color.opacity(0.75)).frame(height: 0.8)
    }
    .frame(width: width)
  }
}

// The plan's progress, as the app's ring
struct Ring<Inner: View>: View {
  let value: Double
  let p: Palette
  var line: CGFloat = 6
  @ViewBuilder var inner: Inner
  var body: some View {
    ZStack {
      Circle().stroke(p.deep, lineWidth: line)
      Circle().trim(from: 0, to: max(0.001, min(1, value)))
        .stroke(p.accent, style: StrokeStyle(lineWidth: line, lineCap: .round))
        .rotationEffect(.degrees(-90))
      inner
    }
  }
}

// The sizes a widget comes in, without WidgetKit's own (so these views draw anywhere)
enum Size { case small, medium, large, rectangular, inline, circular }

func dayKey(_ d: Date) -> String {
  let f = DateFormatter()
  f.calendar = Calendar(identifier: .gregorian)
  f.locale = Locale(identifier: "en_US_POSIX")
  f.timeZone = .current
  f.dateFormat = "yyyy-MM-dd"
  return f.string(from: d)
}
