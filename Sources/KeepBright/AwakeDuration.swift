import Foundation

enum AwakeDuration: Int, CaseIterable {
    case forever = 0
    case fifteenMinutes = 900
    case thirtyMinutes = 1800
    case oneHour = 3600
    case twoHours = 7200

    private static let defaultsKey = "SelectedAwakeDuration"

    var seconds: TimeInterval? {
        rawValue == 0 ? nil : TimeInterval(rawValue)
    }

    var menuTitle: String {
        switch self {
        case .forever:
            return "永久"
        case .fifteenMinutes:
            return "15 分钟"
        case .thirtyMinutes:
            return "30 分钟"
        case .oneHour:
            return "1 小时"
        case .twoHours:
            return "2 小时"
        }
    }

    var notificationBody: String {
        switch self {
        case .forever:
            return "将一直保持亮屏，直到你手动关闭或退出应用。"
        case .fifteenMinutes, .thirtyMinutes, .oneHour, .twoHours:
            return "将在 \(menuTitle) 后自动关闭保持亮屏。"
        }
    }

    static var saved: AwakeDuration {
        let savedValue = UserDefaults.standard.integer(forKey: defaultsKey)
        return AwakeDuration(rawValue: savedValue) ?? .forever
    }

    func save() {
        UserDefaults.standard.set(rawValue, forKey: Self.defaultsKey)
    }
}
