import Foundation

enum AppPreferences {
    private enum Key {
        static let enableOnLaunch = "EnableKeepBrightOnLaunch"
        static let batteryProtectionEnabled = "BatteryProtectionEnabled"
        static let batteryProtectionThreshold = "BatteryProtectionThreshold"
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
            UserDefaults.standard.bool(forKey: Key.batteryProtectionEnabled)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Key.batteryProtectionEnabled)
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

    static func clampedBatteryThreshold(_ value: Int) -> Int {
        min(80, max(5, value))
    }
}
