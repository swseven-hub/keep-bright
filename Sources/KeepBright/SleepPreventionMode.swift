import Foundation

enum SleepPreventionMode: Int, CaseIterable {
    case displayOnly = 0
    case displayAndSystem = 1

    private static let defaultsKey = "SleepPreventionMode"

    var title: String {
        switch self {
        case .displayOnly:
            return "仅保持屏幕常亮"
        case .displayAndSystem:
            return "保持屏幕常亮并防止系统闲置睡眠"
        }
    }

    var shortTitle: String {
        switch self {
        case .displayOnly:
            return "屏幕常亮"
        case .displayAndSystem:
            return "屏幕与系统常醒"
        }
    }

    static var saved: SleepPreventionMode {
        let savedValue = UserDefaults.standard.integer(forKey: defaultsKey)
        return SleepPreventionMode(rawValue: savedValue) ?? .displayOnly
    }

    func save() {
        UserDefaults.standard.set(rawValue, forKey: Self.defaultsKey)
    }
}

enum BatteryProtectionMode: Int, CaseIterable {
    case off = 0
    case notifyOnly = 1
    case autoDisable = 2

    private static let defaultsKey = "BatteryProtectionMode"

    var title: String {
        switch self {
        case .off:
            return "关闭"
        case .notifyOnly:
            return "仅提醒"
        case .autoDisable:
            return "自动关闭保持亮屏"
        }
    }

    static var saved: BatteryProtectionMode {
        if UserDefaults.standard.object(forKey: defaultsKey) == nil {
            return AppPreferences.legacyBatteryProtectionEnabled ? .autoDisable : .off
        }

        let savedValue = UserDefaults.standard.integer(forKey: defaultsKey)
        return BatteryProtectionMode(rawValue: savedValue) ?? .off
    }

    func save() {
        UserDefaults.standard.set(rawValue, forKey: Self.defaultsKey)
    }
}
