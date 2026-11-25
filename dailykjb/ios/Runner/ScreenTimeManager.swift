import Foundation
import UIKit

#if canImport(FamilyControls)
import FamilyControls
#endif

#if canImport(ManagedSettings)
import ManagedSettings
#endif

#if canImport(DeviceActivity)
import DeviceActivity
#endif

/// The settings store shared by the app and its Screen Time extensions.
/// Named, so the app and the extensions are certain to act on the same one.
@available(iOS 16.0, *)
extension ManagedSettingsStore.Name {
    static let dailyKJB = Self("dailykjb")
}

@available(iOS 16.0, *)
extension DeviceActivityName {
    static let daily = Self("dailykjb.daily")
}

/// Manages Screen Time API integration for app blocking.
/// Communicates with Flutter via FlutterMethodChannel.
///
/// How the day goes: at midnight the DeviceActivity schedule starts a new
/// interval and the monitor extension raises the shields on the chosen apps;
/// when the reading is marked read, the app clears them until the next
/// midnight. "blocking_enabled" is the reader's choice and is only changed when
/// they turn Focus Mode on or off.
@available(iOS 16.0, *)
class ScreenTimeManager: NSObject {
    static let shared = ScreenTimeManager()

    private let store = ManagedSettingsStore(named: .dailyKJB)
    private let defaults = UserDefaults(suiteName: "group.com.dailykjb.dailyKjb.shared")

    // Keys for shared UserDefaults
    private let kBlockingEnabled = "blocking_enabled"
    private let kSelectionData = "family_activity_selection"
    private let kReadingCompleteToday = "reading_complete_today"
    private let kLastCompletionDate = "last_completion_date"

    private override init() {
        super.init()
    }

    // MARK: - Authorization

    func requestAuthorization() async throws {
        try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
    }

    var isAuthorized: Bool {
        return AuthorizationCenter.shared.authorizationStatus == .approved
    }

    // MARK: - Selection

    func savedSelection() -> FamilyActivitySelection? {
        guard let data = defaults?.data(forKey: kSelectionData) else { return nil }
        return try? JSONDecoder().decode(FamilyActivitySelection.self, from: data)
    }

    func saveSelection(_ selection: FamilyActivitySelection) {
        if let data = try? JSONEncoder().encode(selection) {
            defaults?.set(data, forKey: kSelectionData)
        }
    }

    func hasSelectedApps() -> Bool {
        return selectedAppCount() > 0
    }

    func selectedAppCount() -> Int {
        guard let s = savedSelection() else { return 0 }
        return s.applicationTokens.count + s.categoryTokens.count + s.webDomainTokens.count
    }

    // MARK: - Shielding

    /// Turn Focus Mode on: remember it, start the daily schedule, and raise the
    /// shields now unless today is already read.
    func enableShields() {
        defaults?.set(true, forKey: kBlockingEnabled)
        startDailySchedule()
        if isReadingCompleteToday() {
            clearShieldsOnly()
        } else {
            applyShields()
        }
    }

    /// Turn Focus Mode off: shields down, schedule stopped.
    func disableShields() {
        defaults?.set(false, forKey: kBlockingEnabled)
        stopDailySchedule()
        clearShieldsOnly()
        // Builds before 1.1 used the default store; clear anything left there
        ManagedSettingsStore().clearAllSettings()
    }

    private func applyShields() {
        guard let selection = savedSelection() else { return }
        store.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
        store.shield.applicationCategories = selection.categoryTokens.isEmpty
            ? nil
            : .specific(selection.categoryTokens)
        store.shield.webDomains = selection.webDomainTokens.isEmpty ? nil : selection.webDomainTokens
    }

    private func clearShieldsOnly() {
        store.clearAllSettings()
    }

    /// Today's reading is done: shields down until the next midnight. Focus
    /// Mode stays on.
    func markReadingComplete() {
        defaults?.set(true, forKey: kReadingCompleteToday)
        defaults?.set(formatDate(Date()), forKey: kLastCompletionDate)
        clearShieldsOnly()
    }

    func isReadingCompleteToday() -> Bool {
        guard let lastDate = defaults?.string(forKey: kLastCompletionDate) else {
            return false
        }
        return lastDate == formatDate(Date())
    }

    /// On opening the app: shields up if Focus Mode is on and today isn't read,
    /// and the schedule running (it may have been lost when the phone restored
    /// from a backup or the app was updated).
    func checkAndReenableShields() {
        let blockingEnabled = defaults?.bool(forKey: kBlockingEnabled) ?? false
        guard blockingEnabled else { return }
        startDailySchedule()
        if isReadingCompleteToday() {
            clearShieldsOnly()
        } else if hasSelectedApps() {
            applyShields()
        }
    }

    // MARK: - The daily schedule

    /// An interval from midnight to the end of each day, repeating. Its start
    /// wakes the monitor extension, which raises the shields for the new day.
    private func startDailySchedule() {
        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59),
            repeats: true
        )
        let center = DeviceActivityCenter()
        if center.activities.contains(.daily) { return }
        do {
            try center.startMonitoring(.daily, during: schedule)
        } catch {
            NSLog("DailyKJB: could not start the daily schedule: \(error)")
        }
    }

    private func stopDailySchedule() {
        DeviceActivityCenter().stopMonitoring([.daily])
    }

    // MARK: - Helpers

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
