import Foundation

enum MenuBarDisplayMode: Int, CaseIterable {
    case iconOnly = 0
    case remainingTime = 1
    case preventionMode = 2
    case statusText = 3

    private static let defaultsKey = "MenuBarDisplayMode"

    var title: String {
        switch self {
        case .iconOnly:
            return "只显示图标"
        case .remainingTime:
            return "显示剩余时间"
        case .preventionMode:
            return "显示防睡眠模式"
        case .statusText:
            return "显示状态文字"
        }
    }

    static var saved: MenuBarDisplayMode {
        guard UserDefaults.standard.object(forKey: defaultsKey) != nil else {
            return .remainingTime
        }

        let savedValue = UserDefaults.standard.integer(forKey: defaultsKey)
        return MenuBarDisplayMode(rawValue: savedValue) ?? .remainingTime
    }

    func save() {
        UserDefaults.standard.set(rawValue, forKey: Self.defaultsKey)
    }
}
