import Flutter
import UIKit
import WidgetKit

/// The home screen's side of the app: the widgets' snapshot, and the links a widget opens the app with
/// (dailykjb://read, dailykjb://verse?ref=John%203:16).
///
/// Channel com.dailykjb/home:
///   update(json)  the widgets' snapshot (lib/services/widget_sync.dart), kept in the app group, widgets refreshed
///   initialLink   the link the app was opened with, if any (asked once on start)
///   shieldReadNow whether a Focus Mode shield's "Read now" just sent the reader here (once, within ten minutes)
///   link(url)     sent to Dart when a link arrives while the app is running
class HomeScreenBridge: NSObject, FlutterPlugin, FlutterSceneLifeCycleDelegate {
  static let channelName = "com.dailykjb/home"
  static let suite = "group.com.dailykjb.dailyKjb.shared"

  private var channel: FlutterMethodChannel?
  private var pending: String?
  private var listening = false

  static func register(with registrar: FlutterPluginRegistrar) {
    let bridge = HomeScreenBridge()
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: registrar.messenger())
    bridge.channel = channel
    registrar.addMethodCallDelegate(bridge, channel: channel)
    registrar.addSceneDelegate(bridge)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "update":
      if let json = call.arguments as? String {
        UserDefaults(suiteName: Self.suite)?.set(json, forKey: "widget_snapshot")
        WidgetCenter.shared.reloadAllTimelines()
      }
      result(nil)
    case "shieldReadNow":
      let d = UserDefaults(suiteName: Self.suite)
      let at = d?.double(forKey: "shield_read_now") ?? 0
      d?.removeObject(forKey: "shield_read_now")
      result(at > 0 && Date().timeIntervalSince1970 - at < 600)
    case "initialLink":
      listening = true
      result(pending)
      pending = nil
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // Opened from a widget: held until Dart asks, or passed on at once if it's running
  private func arrive(_ url: URL?) -> Bool {
    guard let url, url.scheme == "dailykjb" else { return false }
    if listening {
      channel?.invokeMethod("link", arguments: url.absoluteString)
    } else {
      pending = url.absoluteString
    }
    return true
  }

  func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions?) -> Bool {
    arrive(connectionOptions?.urlContexts.first?.url)
  }

  func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) -> Bool {
    arrive(URLContexts.first?.url)
  }
}
