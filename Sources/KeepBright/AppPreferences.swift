import Foundation

enum AppPreferences {
    private enum Key {
        static let enableOnLaunch = "EnableKeepBrightOnLaunch"
        static let batteryProtectionEnabled = "BatteryProtectionEnabled"
        static let batteryProtectionThreshold = "BatteryProtectionThreshold"
        static let restoreAfterPowerConnected = "RestoreAfterPowerConnected"
        static let automaticUpdateChecksEnabled = "AutomaticUpdateChecksEnabled"
        static let menuBarDisplayMode = "MenuBarDisplayMode"
        static let globalHotKeyEnabled = "GlobalHotKeyEnabled"
        static let notifyStatusChanges = "NotifyStatusChanges"
        static let notifyTimerEvents = "NotifyTimerEvents"
        static let notifyBatteryEvents = "NotifyBatteryEvents"
        static let automationAppRulesEnabled = "AutomationAppRulesEnabled"
        static let automationFullscreenEnabled = "AutomationFullscreenEnabled"
        static let automationExternalDisplayEnabled = "AutomationExternalDisplayEnabled"
        static let automationPowerAdapterEnabled = "AutomationPowerAdapterEnabled"
        static let automationAppRules = "AutomationAppRules"
        static let customDurationMinutes = "CustomDurationMinutes"
        static let hasSeenFirstLaunchGuide = "HasSeenFirstLaunchGuide"
    }

    static let defaultAutomationAppRules = [
        "Keynote",
        "Microsoft PowerPoint",
        "zoom.us",
        "Zoom",
        "Microsoft Teams",
        "腾讯会议",
        "QuickTime Player",
        "VLC"
    ]

    static var enableOnLaunch: Bool {
        get {
            if UserDefaults.standard.object(forKey: Key.enableOnLaunch) == nil {
                return true
            }

            return UserDefaults.standard.bool(forKey: Key.enableOnLaunch)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Key.enableOnLaunch)
        }
    }

    static var batteryProtectionEnabled: Bool {
        get {
            batteryProtectionMode != .off
        }
        set {
            batteryProtectionMode = newValue ? .autoDisable : .off
        }
    }

    static var legacyBatteryProtectionEnabled: Bool {
        UserDefaults.standard.bool(forKey: Key.batteryProtectionEnabled)
    }

    static var batteryProtectionMode: BatteryProtectionMode {
        get {
            BatteryProtectionMode.saved
        }
        set {
            newValue.save()
            UserDefaults.standard.set(newValue != .off, forKey: Key.batteryProtectionEnabled)
        }
    }

    static var sleepPreventionMode: SleepPreventionMode {
        get {
            SleepPreventionMode.saved
        }
        set {
            newValue.save()
        }
    }

    static var batteryProtectionThreshold: Int {
        get {
            let savedValue = UserDefaults.standard.integer(forKey: Key.batteryProtectionThreshold)
            return savedValue == 0 ? 20 : clampedBatteryThreshold(savedValue)
        }
        set {
            UserDefaults.standard.set(clampedBatteryThreshold(newValue), forKey: Key.batteryProtectionThreshold)
        }
    }

    static var automaticUpdateChecksEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: Key.automaticUpdateChecksEnabled) == nil {
                return true
            }

            return UserDefaults.standard.bool(forKey: Key.automaticUpdateChecksEnabled)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Key.automaticUpdateChecksEnabled)
        }
    }

    static var restoreAfterPowerConnected: Bool {
        get {
            if UserDefaults.standard.object(forKey: Key.restoreAfterPowerConnected) == nil {
                return true
            }

            return UserDefaults.standard.bool(forKey: Key.restoreAfterPowerConnected)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Key.restoreAfterPowerConnected)
        }
    }

    static var menuBarDisplayMode: MenuBarDisplayMode {
        get {
            MenuBarDisplayMode.saved
        }
        set {
            newValue.save()
        }
    }

    static var globalHotKeyEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: Key.globalHotKeyEnabled) == nil {
                return true
            }

            return UserDefaults.standard.bool(forKey: Key.globalHotKeyEnabled)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Key.globalHotKeyEnabled)
        }
    }

    static var notifyStatusChanges: Bool {
        get {
            if UserDefaults.standard.object(forKey: Key.notifyStatusChanges) == nil {
                return true
            }

            return UserDefaults.standard.bool(forKey: Key.notifyStatusChanges)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Key.notifyStatusChanges)
        }
    }

    static var notifyTimerEvents: Bool {
        get {
            if UserDefaults.standard.object(forKey: Key.notifyTimerEvents) == nil {
                return true
            }

            return UserDefaults.standard.bool(forKey: Key.notifyTimerEvents)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Key.notifyTimerEvents)
        }
    }

    static var notifyBatteryEvents: Bool {
        get {
            if UserDefaults.standard.object(forKey: Key.notifyBatteryEvents) == nil {
                return true
            }

            return UserDefaults.standard.bool(forKey: Key.notifyBatteryEvents)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Key.notifyBatteryEvents)
        }
    }

    static var automationAppRulesEnabled: Bool {
        get {
            UserDefaults.standard.bool(forKey: Key.automationAppRulesEnabled)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Key.automationAppRulesEnabled)
        }
    }

    static var automationFullscreenEnabled: Bool {
        get {
            UserDefaults.standard.bool(forKey: Key.automationFullscreenEnabled)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Key.automationFullscreenEnabled)
        }
    }

    static var automationExternalDisplayEnabled: Bool {
        get {
            UserDefaults.standard.bool(forKey: Key.automationExternalDisplayEnabled)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Key.automationExternalDisplayEnabled)
        }
    }

    static var automationPowerAdapterEnabled: Bool {
        get {
            UserDefaults.standard.bool(forKey: Key.automationPowerAdapterEnabled)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Key.automationPowerAdapterEnabled)
        }
    }

    static var automationAppRules: [String] {
        get {
            guard UserDefaults.standard.object(forKey: Key.automationAppRules) != nil else {
                return defaultAutomationAppRules
            }

            return UserDefaults.standard.stringArray(forKey: Key.automationAppRules) ?? defaultAutomationAppRules
        }
        set {
            let rules = newValue
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            UserDefaults.standard.set(rules, forKey: Key.automationAppRules)
        }
    }

    static var customDurationMinutes: Int {
        get {
            let savedValue = UserDefaults.standard.integer(forKey: Key.customDurationMinutes)
            return savedValue == 0 ? 45 : clampedCustomDurationMinutes(savedValue)
        }
        set {
            UserDefaults.standard.set(clampedCustomDurationMinutes(newValue), forKey: Key.customDurationMinutes)
        }
    }

    static var hasSeenFirstLaunchGuide: Bool {
        get {
            UserDefaults.standard.bool(forKey: Key.hasSeenFirstLaunchGuide)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Key.hasSeenFirstLaunchGuide)
        }
    }

    static func clampedBatteryThreshold(_ value: Int) -> Int {
        min(80, max(5, value))
    }

    static func clampedCustomDurationMinutes(_ value: Int) -> Int {
        min(720, max(1, value))
    }
}
