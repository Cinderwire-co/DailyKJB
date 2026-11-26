// Draws Focus Mode's shield, the screen a locked app shows, at the App Store's screenshot sizes, for the store art
// (Screen Time doesn't run in the simulator). Its words and colors are the app's own
// (dailykjb/ios/ShieldConfiguration/ShieldConfigurationExtension.swift); the layout follows iOS's shield, in the
// system font, as the real one is drawn.
//
//   swiftc -parse-as-library -target arm64-apple-macos14 tools/shield_shot.swift -o /tmp/shield_shot
//   /tmp/shield_shot <out-dir>      writes shield-iphone-6.9.png, shield-iphone-6.3.png, shield-ipad-13.png
import AppKit
import SwiftUI

let parchment = Color(red: 0.953, green: 0.914, blue: 0.843)
let ink = Color(red: 0.165, green: 0.118, blue: 0.082)
let faded = Color(red: 0.486, green: 0.408, blue: 0.322)
let accent = Color(red: 0.753, green: 0.388, blue: 0.169)

struct StatusBar: View {
  let pad: Bool
  var body: some View {
    HStack {
      Text("9:41").font(.system(size: pad ? 15 : 17, weight: .semibold))
      Spacer()
      HStack(spacing: 6) {
        if !pad { Image(systemName: "cellularbars") }
        Image(systemName: "wifi")
        Image(systemName: "battery.100")
      }
      .font(.system(size: pad ? 14 : 16, weight: .semibold))
    }
    .foregroundStyle(ink)
    .padding(.horizontal, pad ? 22 : 34)
    .padding(.top, pad ? 10 : 18)
  }
}

struct Shield: View {
  let size: CGSize
  let pad: Bool
  var body: some View {
    ZStack {
      // Behind the shield, a blurred glimpse of the locked app, under the app's parchment
      LinearGradient(colors: [Color(red: 0.55, green: 0.62, blue: 0.75), Color(red: 0.85, green: 0.55, blue: 0.6)],
                     startPoint: .topLeading, endPoint: .bottomTrailing)
      parchment.opacity(0.96)
      VStack(spacing: 0) {
        StatusBar(pad: pad)
        Spacer()
        VStack(spacing: pad ? 18 : 16) {
          Image(systemName: "book.closed.fill")
            .font(.system(size: pad ? 64 : 56))
            .foregroundStyle(accent)
            .padding(.bottom, 6)
          Text("The Word first")
            .font(.system(size: pad ? 30 : 26, weight: .bold))
            .foregroundStyle(ink)
          Text("This app opens once today's reading is done in DailyKJB.\n\n\"Seek ye first the kingdom of God.\" Matthew 6:33")
            .font(.system(size: pad ? 19 : 17))
            .foregroundStyle(faded)
            .multilineTextAlignment(.center)
            .frame(maxWidth: pad ? 460 : 330)
        }
        Spacer()
        VStack(spacing: pad ? 14 : 12) {
          Text("Read now")
            .font(.system(size: pad ? 19 : 17, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: pad ? 420 : .infinity)
            .frame(height: pad ? 56 : 52)
            .background(accent, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
          Text("Close")
            .font(.system(size: pad ? 19 : 17))
            .foregroundStyle(faded)
            .frame(height: 36)
        }
        .padding(.horizontal, pad ? 0 : 28)
        .padding(.bottom, pad ? 48 : 56)
      }
    }
    .frame(width: size.width, height: size.height)
  }
}

@main
struct ShieldShot {
  @MainActor static func main() {
    let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."
    for (name, points, scale, pad) in [("iphone-6.9", CGSize(width: 440, height: 956), 3.0, false),
                                       ("iphone-6.3", CGSize(width: 402, height: 874), 3.0, false),
                                       ("ipad-13", CGSize(width: 1032, height: 1376), 2.0, true)] {
      let r = ImageRenderer(content: Shield(size: points, pad: pad).environment(\.colorScheme, .light))
      r.scale = scale
      guard let img = r.nsImage, let tiff = img.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
            let png = rep.representation(using: .png, properties: [:]) else { continue }
      let path = "\(out)/shield-\(name).png"
      try? png.write(to: URL(fileURLWithPath: path))
      print(path, rep.pixelsWide, "x", rep.pixelsHigh)
    }
  }
}
