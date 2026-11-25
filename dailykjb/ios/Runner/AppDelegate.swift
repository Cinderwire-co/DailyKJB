import Flutter
import UIKit
import flutter_local_notifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let appBlockingChannel = AppBlockingChannel()
  private let aiChannel = AIChannel()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    FlutterLocalNotificationsPlugin.setPluginRegistrantCallback { (registry) in
      GeneratedPluginRegistrant.register(with: registry)
    }
    UNUserNotificationCenter.current().delegate = self as UNUserNotificationCenterDelegate
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // The engine the storyboard's FlutterViewController makes (UIScene lifecycle,
  // which iOS 27 requires): plugins, and the app's own channels for Screen Time
  // (Focus Mode), Apple Intelligence, and the home screen (widgets and their links)
  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "DailyKJBHomeScreen") {
      HomeScreenBridge.register(with: registrar)
    }
    let messenger = engineBridge.applicationRegistrar.messenger()
    appBlockingChannel.register(with: messenger)
    aiChannel.register(with: messenger)
  }
}
