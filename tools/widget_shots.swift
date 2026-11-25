// Draws the home screen widgets on the Mac, at the sizes an iPhone shows them, in parchment and lamplight, to look at
// without a phone. The views are the widgets' own (dailykjb/ios/DailyKJBWidgets); only WidgetKit is left out.
//
//   swiftc -parse-as-library -target arm64-apple-macos14 \
//     dailykjb/ios/DailyKJBWidgets/{Look,Snapshot,Views}.swift tools/widget_shots.swift -o /tmp/widget_shots
//   /tmp/widget_shots <out-dir>
import AppKit
import CoreText
import SwiftUI

@main
struct WidgetShots {
  @MainActor static func main() {
    let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    for f in ["Cinzel-SemiBold", "EBGaramond-Regular", "EBGaramond-Italic", "EBGaramond-SemiBold"] {
      CTFontManagerRegisterFontsForURL(root.appendingPathComponent("dailykjb/assets/fonts/\(f).ttf") as CFURL, .process, nil)
    }
    let read = Day(read: true, complete: false,
                   next: Snapshot.Reading(day: 42, title: "Leviticus 24–25; Psalm 42", short: "Lev. 24–25; Psa. 42", minutes: 11),
                   calendarDay: 41, catchUp: false, streak: 24, share: 0.112, completed: 41, total: 365, plan: "Whole Bible")
    for (name, p) in [("light", Palette.parchment), ("dark", Palette.lamplight)] {
      let sheet = VStack(alignment: .leading, spacing: 24) {
        HStack(alignment: .top, spacing: 24) {
          card(p, 170, 170) { TodayView(day: Sample.day, size: .small, p: p) }
          card(p, 170, 170) { TodayView(day: read, size: .small, p: p) }
          card(p, 170, 170) { VerseView(verse: Sample.verse, size: .small, p: p) }
        }
        card(p, 364, 170) { TodayView(day: Sample.day, size: .medium, p: p) }
        card(p, 364, 170) { TodayView(day: read, size: .medium, p: p) }
        card(p, 364, 170) { VerseView(verse: Sample.verse, size: .medium, p: p) }
        card(p, 364, 382) { VerseView(verse: Sample.verse, size: .large, p: p) }
        HStack(spacing: 16) {
          lock(172, 76) { TodayView(day: Sample.day, size: .rectangular, p: p) }
          lock(172, 76) { VerseView(verse: Sample.verse, size: .rectangular, p: p) }
        }
      }
      .padding(24)
      .background(Color(white: name == "dark" ? 0.08 : 0.9))
      let r = ImageRenderer(content: sheet)
      r.scale = 2
      if let img = r.nsImage, let tiff = img.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
         let png = rep.representation(using: .png, properties: [:]) {
        try? png.write(to: URL(fileURLWithPath: "\(out)/widgets-\(name).png"))
        print("\(out)/widgets-\(name).png")
      }
    }
  }

  @MainActor static func card<V: View>(_ p: Palette, _ w: CGFloat, _ h: CGFloat, @ViewBuilder _ v: () -> V) -> some View {
    v().padding(16).frame(width: w, height: h).background(PaperBack(p: p)).clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
  }

  @MainActor static func lock<V: View>(_ w: CGFloat, _ h: CGFloat, @ViewBuilder _ v: () -> V) -> some View {
    v().foregroundStyle(.white).padding(8).frame(width: w, height: h)
      .background(Color(white: 0.25)).clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
  }
}
