import Foundation

enum AppPreferences {
    private enum Key {
        static let enableOnLaunch = "EnableKeepBrightOnLaunch"
        static let batteryProtectionEnabled = "BatteryProtectionEnabled"
        static let batteryProtectionThreshold = "BatteryProtectionThreshold"
        static let restoreAfterPowerConnected = "RestoreAfterPowerConnected"
        static let automaticUpdateChecksEnabled = "AutomaticUpdateChecksEnabled"
        static let customDurationMinutes = "CustomDurationMinutes"
        static let hasSeenFirstLaunchGuide = "HasSeenFirstLaunchGuide"
    }

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
