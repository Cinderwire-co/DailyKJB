import DeviceActivity
import FamilyControls
import ManagedSettings
import Foundation

extension ManagedSettingsStore.Name {
    // The same store the app uses (Runner/ScreenTimeManager.swift)
    static let dailyKJB = Self("dailykjb")
}

/// Woken by the app's daily schedule: at midnight a new interval starts, and
/// the chosen apps close until the day's reading is done.
class DeviceActivityMonitorExtension: DeviceActivityMonitor {
    let store = ManagedSettingsStore(named: .dailyKJB)
    private let suiteName = "group.com.dailykjb.dailyKjb.shared"
    private let kBlockingEnabled = "blocking_enabled"
    private let kSelectionData = "family_activity_selection"
    private let kLastCompletionDate = "last_completion_date"

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        let defaults = UserDefaults(suiteName: suiteName)
        guard defaults?.bool(forKey: kBlockingEnabled) ?? false else { return }
        if !isReadingCompleteToday(defaults: defaults) {
            applyShields(defaults: defaults)
        }
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        // 23:59: the next interval's start, a minute later, raises the shields
        // for the new day. Nothing to do here.
    }

    private func isReadingCompleteToday(defaults: UserDefaults?) -> Bool {
        guard let lastDate = defaults?.string(forKey: kLastCompletionDate) else {
            return false
        }
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return lastDate == formatter.string(from: Date())
    }

    private func applyShields(defaults: UserDefaults?) {
        guard let data = defaults?.data(forKey: kSelectionData),
              let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) else {
            return
        }
        store.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
        store.shield.applicationCategories = selection.categoryTokens.isEmpty
            ? nil
            : ShieldSettings.ActivityCategoryPolicy.specific(selection.categoryTokens)
        store.shield.webDomains = selection.webDomainTokens.isEmpty ? nil : selection.webDomainTokens
    }
}
