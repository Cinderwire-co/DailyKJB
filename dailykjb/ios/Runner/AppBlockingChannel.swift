import Flutter
import UIKit

#if canImport(FamilyControls)
import FamilyControls
#endif

#if canImport(SwiftUI)
import SwiftUI
#endif

/// Flutter MethodChannel handler for app blocking features.
/// Bridges between Dart and native iOS Screen Time API.
class AppBlockingChannel: NSObject {
    static let channelName = "com.dailykjb/app_blocking"

    private var channel: FlutterMethodChannel?

    func register(with messenger: FlutterBinaryMessenger) {
        channel = FlutterMethodChannel(name: AppBlockingChannel.channelName, binaryMessenger: messenger)
        channel?.setMethodCallHandler(handle)
    }

    private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        if #available(iOS 16.0, *) {
            handleiOS16(call, result: result)
        } else {
            result(FlutterError(code: "UNSUPPORTED", message: "Screen Time API requires iOS 16+", details: nil))
        }
    }

    @available(iOS 16.0, *)
    private func handleiOS16(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let manager = ScreenTimeManager.shared

        switch call.method {
        case "isSupported":
            result(true)

        case "requestAuthorization":
            Task {
                do {
                    try await manager.requestAuthorization()
                    DispatchQueue.main.async { result(manager.isAuthorized) }
                } catch {
                    DispatchQueue.main.async { result(false) }
                }
            }

        case "isAuthorized":
            result(manager.isAuthorized)

        case "showAppPicker":
            showFamilyActivityPicker(result: result)

        case "enableBlocking":
            manager.enableShields()
            result(true)

        case "disableBlocking":
            manager.disableShields()
            result(true)

        case "markReadingComplete":
            manager.markReadingComplete()
            result(true)

        case "isReadingCompleteToday":
            result(manager.isReadingCompleteToday())

        case "checkAndReenableShields":
            manager.checkAndReenableShields()
            result(true)

        case "hasSelectedApps":
            result(manager.hasSelectedApps())

        case "selectedAppCount":
            result(manager.selectedAppCount())

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    @available(iOS 16.0, *)
    private func showFamilyActivityPicker(result: @escaping FlutterResult) {
        guard let rootVC = Self.topViewController() else {
            result(FlutterError(code: "NO_VC", message: "No view controller to present from", details: nil))
            return
        }

        // Answer Flutter exactly once, however the picker goes away
        var answered = false
        let answer: () -> Void = {
            guard !answered else { return }
            answered = true
            result(ScreenTimeManager.shared.selectedAppCount())
        }

        let pickerVC = UIHostingController(rootView: FamilyActivityPickerView(
            initial: ScreenTimeManager.shared.savedSelection() ?? FamilyActivitySelection(),
            onDone: { selection in
                ScreenTimeManager.shared.saveSelection(selection)
                answer()
            },
            onClose: answer
        ))
        pickerVC.modalPresentationStyle = .pageSheet
        if let sheet = pickerVC.sheetPresentationController {
            sheet.detents = [.large()]
        }
        rootVC.present(pickerVC, animated: true)
    }

    static func topViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let window = scenes.flatMap { $0.windows }.first { $0.isKeyWindow } ?? scenes.first?.windows.first
        var top = window?.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        return top
    }
}

// MARK: - SwiftUI FamilyActivityPicker wrapper

@available(iOS 16.0, *)
struct FamilyActivityPickerView: View {
    @State private var selection: FamilyActivitySelection
    @Environment(\.dismiss) private var dismiss

    let onDone: (FamilyActivitySelection) -> Void
    let onClose: () -> Void

    init(initial: FamilyActivitySelection, onDone: @escaping (FamilyActivitySelection) -> Void, onClose: @escaping () -> Void) {
        _selection = State(initialValue: initial)
        self.onDone = onDone
        self.onClose = onClose
    }

    var body: some View {
        NavigationView {
            FamilyActivityPicker(selection: $selection)
                .navigationTitle("Apps to keep closed")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            dismiss()
                            onClose()
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            onDone(selection)
                            dismiss()
                        }
                        .fontWeight(.semibold)
                    }
                }
        }
        .tint(Color(red: 0.75, green: 0.39, blue: 0.17))
        // Swiped down, or anything else that closes it
        .onDisappear { onClose() }
    }
}
