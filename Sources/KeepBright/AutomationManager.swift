import AppKit
import CoreGraphics

enum AutomationTrigger: String, CaseIterable {
    case app
    case fullscreen
    case externalDisplay
    case powerAdapter

    var title: String {
        switch self {
        case .app:
            return "指定 App"
        case .fullscreen:
            return "全屏"
        case .externalDisplay:
            return "外接显示器"
        case .powerAdapter:
            return "已连接电源"
        }
    }
}

struct AutomationEvaluation: Equatable {
    let triggers: [AutomationTrigger]

    static let inactive = AutomationEvaluation(triggers: [])

    var isActive: Bool {
        !triggers.isEmpty
    }

    var summary: String {
        triggers.map(\.title).joined(separator: "、")
    }
}

final class AutomationManager {
    var onChange: ((AutomationEvaluation) -> Void)?

    private let workspace = NSWorkspace.shared
    private let batteryMonitor = BatteryMonitor()
    private var timer: Timer?
    private var lastEvaluation: AutomationEvaluation?
    private var observers: [NSObjectProtocol] = []

    func start() {
        stop()

        let center = workspace.notificationCenter
        observers = [
            center.addObserver(
                forName: NSWorkspace.didActivateApplicationNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.evaluate()
            },
            NotificationCenter.default.addObserver(
                forName: NSApplication.didChangeScreenParametersNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.evaluate()
            }
        ]

        refreshPollingTimer()
        evaluate()
    }

    func stop() {
        timer?.invalidate()
        timer = nil

        for observer in observers {
            workspace.notificationCenter.removeObserver(observer)
            NotificationCenter.default.removeObserver(observer)
        }
        observers.removeAll()
        lastEvaluation = nil
    }

    func evaluateNow() {
        refreshPollingTimer()
        evaluate()
    }

    private func evaluate() {
        let evaluation = currentEvaluation()
        guard evaluation != lastEvaluation else {
            return
        }

        lastEvaluation = evaluation
        onChange?(evaluation)
    }

    private func currentEvaluation() -> AutomationEvaluation {
        guard hasEnabledAutomation else {
            return .inactive
        }

        var triggers: [AutomationTrigger] = []

        if AppPreferences.automationAppRulesEnabled, activeAppMatchesRules() {
            triggers.append(.app)
        }

        if AppPreferences.automationFullscreenEnabled, frontmostAppHasFullscreenWindow() {
            triggers.append(.fullscreen)
        }

        if AppPreferences.automationExternalDisplayEnabled, NSScreen.screens.count > 1 {
            triggers.append(.externalDisplay)
        }

        if AppPreferences.automationPowerAdapterEnabled, batteryMonitor.currentState().isConnectedToPower {
            triggers.append(.powerAdapter)
        }

        return AutomationEvaluation(triggers: triggers)
    }

    private var hasEnabledAutomation: Bool {
        AppPreferences.automationAppRulesEnabled
            || AppPreferences.automationFullscreenEnabled
            || AppPreferences.automationExternalDisplayEnabled
            || AppPreferences.automationPowerAdapterEnabled
    }

    private var preferredPollingInterval: TimeInterval? {
        if AppPreferences.automationFullscreenEnabled {
            return 5
        }

        if AppPreferences.automationPowerAdapterEnabled {
            return 60
        }

        return nil
    }

    private func refreshPollingTimer() {
        let interval = preferredPollingInterval
        if timer?.timeInterval == interval {
            return
        }

        timer?.invalidate()
        timer = nil

        guard let interval else {
            return
        }

        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            self?.evaluate()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func activeAppMatchesRules() -> Bool {
        guard let app = workspace.frontmostApplication,
              !app.isKeepBright else {
            return false
        }

        let appName = app.localizedName?.normalizedAutomationToken ?? ""
        let bundleID = app.bundleIdentifier?.normalizedAutomationToken ?? ""

        return AppPreferences.automationAppRules.contains { rule in
            let token = rule.normalizedAutomationToken
            guard !token.isEmpty else {
                return false
            }

            return appName.contains(token) || bundleID == token || bundleID.contains(token)
        }
    }

    private func frontmostAppHasFullscreenWindow() -> Bool {
        guard let app = workspace.frontmostApplication,
              !app.isKeepBright else {
            return false
        }

        let pid = app.processIdentifier
        guard let windowList = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else {
            return false
        }

        return windowList.contains { info in
            guard let ownerPID = info[kCGWindowOwnerPID as String] as? pid_t,
                  ownerPID == pid,
                  let layer = info[kCGWindowLayer as String] as? Int,
                  layer == 0,
                  let bounds = info[kCGWindowBounds as String] as? [String: Any],
                  let rect = CGRect(dictionaryRepresentation: bounds as CFDictionary),
                  rect.width > 0,
                  rect.height > 0 else {
                return false
            }

            return rect.isFullscreenLike
        }
    }
}

private extension CGRect {
    var isFullscreenLike: Bool {
        NSScreen.screens.contains { screen in
            let screenFrame = screen.frame
            let tolerance: CGFloat = 12
            return abs(minX - screenFrame.minX) <= tolerance
                && abs(minY - screenFrame.minY) <= tolerance
                && abs(width - screenFrame.width) <= tolerance
                && abs(height - screenFrame.height) <= tolerance
        }
    }
}

private extension NSRunningApplication {
    var isKeepBright: Bool {
        bundleIdentifier == Bundle.main.bundleIdentifier
    }
}

private extension String {
    var normalizedAutomationToken: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
    }
}
