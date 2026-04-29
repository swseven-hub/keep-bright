import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let assertion = DisplaySleepAssertion()
    private let notifier = NotificationManager()
    private let updateChecker = UpdateChecker()
    private let batteryMonitor = BatteryMonitor()

    private var statusItem: NSStatusItem?
    private let statusItemLabel = NSMenuItem()
    private let toggleItem = NSMenuItem()
    private let durationMenu = NSMenu()
    private let launchAtLoginItem = NSMenuItem()
    private let checkForUpdatesItem = NSMenuItem()
    private let preferencesItem = NSMenuItem()
    private var preferencesWindowController: PreferencesWindowController?

    private var selectedDuration = AwakeDuration.saved
    private var activeUntil: Date?
    private var countdownTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        configureBatteryProtection()
        configureMenuBarItem()

        if AppPreferences.enableOnLaunch {
            setKeepBrightEnabled(true, notify: false)
        } else {
            updateMenuState()
        }

        checkForUpdatesAutomaticallyIfNeeded()
    }

    func applicationWillTerminate(_ notification: Notification) {
        countdownTimer?.invalidate()
        batteryMonitor.stop()
        assertion.disable()
    }

    private func configureMenuBarItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem = item

        if let button = item.button {
            button.image = statusImage(isEnabled: false)
            button.imagePosition = .imageOnly
            button.toolTip = "保持亮屏"
            button.setAccessibilityLabel("保持亮屏")
        }

        let menu = NSMenu()
        statusItemLabel.title = "保持亮屏：准备开启"
        statusItemLabel.isEnabled = false
        menu.addItem(statusItemLabel)
        menu.addItem(.separator())

        toggleItem.title = "关闭保持亮屏"
        toggleItem.target = self
        toggleItem.action = #selector(toggleKeepBright)
        menu.addItem(toggleItem)

        let durationItem = NSMenuItem(title: "保持时长", action: nil, keyEquivalent: "")
        durationItem.submenu = durationMenu
        configureDurationMenu()
        menu.addItem(durationItem)

        launchAtLoginItem.title = "开机自启动"
        launchAtLoginItem.target = self
        launchAtLoginItem.action = #selector(toggleLaunchAtLogin)
        menu.addItem(launchAtLoginItem)

        menu.addItem(.separator())

        preferencesItem.title = "偏好设置..."
        preferencesItem.target = self
        preferencesItem.action = #selector(showPreferences)
        preferencesItem.keyEquivalent = ","
        menu.addItem(preferencesItem)

        checkForUpdatesItem.title = "检查更新..."
        checkForUpdatesItem.target = self
        checkForUpdatesItem.action = #selector(checkForUpdatesManually)
        menu.addItem(checkForUpdatesItem)

        let aboutItem = NSMenuItem(
            title: "关于保持亮屏",
            action: #selector(showAbout),
            keyEquivalent: ""
        )
        aboutItem.target = self
        menu.addItem(aboutItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "退出保持亮屏",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        quitItem.target = NSApp
        menu.addItem(quitItem)

        item.menu = menu
        updateMenuState()
    }

    private func configureDurationMenu() {
        durationMenu.removeAllItems()

        for duration in AwakeDuration.allCases {
            let item = NSMenuItem(
                title: duration.menuTitle,
                action: #selector(selectDuration(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = duration.rawValue
            durationMenu.addItem(item)
        }
    }

    @objc private func toggleKeepBright() {
        setKeepBrightEnabled(!assertion.isActive, notify: true)
    }

    @objc private func selectDuration(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? Int,
              let duration = AwakeDuration(rawValue: rawValue) else {
            return
        }

        selectedDuration = duration
        selectedDuration.save()

        if assertion.isActive {
            startTimedSession(for: duration)
            notifier.send(
                title: "保持时长已更新",
                body: duration.notificationBody
            )
        }

        updateMenuState()
    }

    @objc private func toggleLaunchAtLogin() {
        do {
            try LoginItemManager.setEnabled(!LoginItemManager.isEnabled)
            updateMenuState()

            let isEnabled = LoginItemManager.isEnabled
            notifier.send(
                title: isEnabled ? "已开启开机自启动" : "已关闭开机自启动",
                body: isEnabled ? "Keep Bright 会在你登录 macOS 后自动启动。" : "Keep Bright 不会在登录后自动启动。"
            )
        } catch {
            updateMenuState()
            showLoginItemError(error)
        }
    }

    @objc private func showPreferences() {
        if preferencesWindowController == nil {
            let controller = PreferencesWindowController()
            controller.onPreferencesChanged = { [weak self] in
                self?.preferencesDidChange()
            }
            preferencesWindowController = controller
        }

        preferencesWindowController?.show()
    }

    @objc private func checkForUpdatesManually() {
        checkForUpdatesItem.isEnabled = false
        checkForUpdatesItem.title = "正在检查更新..."

        updateChecker.check { [weak self] result in
            guard let self else {
                return
            }

            self.checkForUpdatesItem.isEnabled = true
            self.checkForUpdatesItem.title = "检查更新..."
            self.handleUpdateCheckResult(result, isAutomatic: false)
        }
    }

    private func setKeepBrightEnabled(_ isEnabled: Bool, notify: Bool) {
        if isEnabled {
            if let batteryState = batteryMonitor.shouldPreventEnabling() {
                stopCountdown()
                assertion.disable()
                updateMenuState()

                if notify {
                    showBatteryProtectionAlert(batteryState)
                }
                return
            }

            guard assertion.enable() else {
                stopCountdown()
                updateMenuState()
                showAssertionError()
                return
            }

            startTimedSession(for: selectedDuration)

            if notify {
                notifier.send(
                    title: "保持亮屏已开启",
                    body: selectedDuration.notificationBody
                )
            }
        } else {
            stopCountdown()
            assertion.disable()

            if notify {
                notifier.send(
                    title: "保持亮屏已关闭",
                    body: "屏幕将恢复系统默认节能策略。"
                )
            }
        }

        updateMenuState()
    }

    private func configureBatteryProtection() {
        batteryMonitor.onProtectionTriggered = { [weak self] state in
            DispatchQueue.main.async {
                self?.applyBatteryProtection(state)
            }
        }
        batteryMonitor.start()
    }

    private func preferencesDidChange() {
        if let state = batteryMonitor.shouldPreventEnabling(), assertion.isActive {
            applyBatteryProtection(state)
        }

        updateMenuState()
    }

    private func applyBatteryProtection(_ state: BatteryState) {
        guard assertion.isActive else {
            return
        }

        stopCountdown()
        assertion.disable()
        updateMenuState()

        let chargeText = state.chargePercent.map { "\($0)%" } ?? "当前"
        notifier.send(
            title: "已因低电量关闭保持亮屏",
            body: "电量 \(chargeText)，低于 \(AppPreferences.batteryProtectionThreshold)% 阈值。"
        )
    }

    private func startTimedSession(for duration: AwakeDuration) {
        stopCountdown()

        guard let seconds = duration.seconds else {
            updateMenuState()
            return
        }

        activeUntil = Date().addingTimeInterval(seconds)
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            self?.tickCountdown()
        }
        RunLoop.main.add(timer, forMode: .common)
        countdownTimer = timer
        updateMenuState()
    }

    private func stopCountdown() {
        countdownTimer?.invalidate()
        countdownTimer = nil
        activeUntil = nil
    }

    private func tickCountdown() {
        guard assertion.isActive else {
            stopCountdown()
            updateMenuState()
            return
        }

        guard remainingSeconds > 0 else {
            stopCountdown()
            assertion.disable()
            updateMenuState()
            notifier.send(
                title: "定时保持亮屏已结束",
                body: "屏幕已恢复系统默认节能策略。"
            )
            return
        }

        updateMenuState()
    }

    private var remainingSeconds: Int {
        guard let activeUntil else {
            return 0
        }

        return max(0, Int(ceil(activeUntil.timeIntervalSinceNow)))
    }

    private func updateMenuState() {
        let isEnabled = assertion.isActive
        statusItemLabel.title = statusText(isEnabled: isEnabled)
        toggleItem.title = isEnabled ? "关闭保持亮屏" : "开启保持亮屏"
        toggleItem.state = isEnabled ? .on : .off

        for item in durationMenu.items {
            guard let rawValue = item.representedObject as? Int,
                  let duration = AwakeDuration(rawValue: rawValue) else {
                continue
            }
            item.state = duration == selectedDuration ? .on : .off
        }

        updateLaunchAtLoginItem()

        if let button = statusItem?.button {
            button.image = statusImage(isEnabled: isEnabled)
            button.title = menuBarTitle(isEnabled: isEnabled)
            button.imagePosition = button.title.isEmpty ? .imageOnly : .imageLeading
            button.toolTip = statusText(isEnabled: isEnabled)
            button.setAccessibilityLabel(statusText(isEnabled: isEnabled))
        }
    }

    private func updateLaunchAtLoginItem() {
        switch LoginItemManager.status {
        case .enabled:
            launchAtLoginItem.title = "开机自启动"
            launchAtLoginItem.state = .on
        case .requiresApproval:
            launchAtLoginItem.title = "开机自启动（需要在系统设置中批准）"
            launchAtLoginItem.state = .mixed
        case .notRegistered, .notFound:
            launchAtLoginItem.title = "开机自启动"
            launchAtLoginItem.state = .off
        @unknown default:
            launchAtLoginItem.title = "开机自启动"
            launchAtLoginItem.state = .off
        }
    }

    private func checkForUpdatesAutomaticallyIfNeeded() {
        updateChecker.checkAutomatically { [weak self] result in
            self?.handleUpdateCheckResult(result, isAutomatic: true)
        }
    }

    private func handleUpdateCheckResult(_ result: UpdateCheckResult, isAutomatic: Bool) {
        switch result {
        case .updateAvailable(let info):
            showUpdateAvailable(info)
        case .upToDate(let currentVersion, let latestVersion):
            if !isAutomatic {
                showUpToDateAlert(currentVersion: currentVersion, latestVersion: latestVersion)
            }
        case .failed(let message):
            if !isAutomatic {
                showUpdateError(message)
            }
        }
    }

    private func showUpdateAvailable(_ info: UpdateInfo) {
        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.messageText = "发现新版本 \(info.latestVersion)"
        alert.informativeText = "当前版本：\(info.currentVersion)\n最新版本：\(info.latestVersion)\n发布名称：\(info.releaseName)\n\n是否打开 GitHub Releases 下载新版本？"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "打开下载页面")
        alert.addButton(withTitle: "稍后")

        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.open(info.releaseURL)
        }
    }

    private func showUpToDateAlert(currentVersion: String, latestVersion: String) {
        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.messageText = "已是最新版本"
        alert.informativeText = "当前版本：\(currentVersion)\nGitHub 最新版本：\(latestVersion)"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "好")
        alert.runModal()
    }

    private func showUpdateError(_ message: String) {
        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.messageText = "检查更新失败"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "好")
        alert.runModal()
    }

    private func statusText(isEnabled: Bool) -> String {
        guard isEnabled else {
            return "保持亮屏：已关闭"
        }

        if activeUntil != nil {
            return "保持亮屏：剩余 \(formattedRemainingTime())"
        }

        return "保持亮屏：已开启（永久）"
    }

    private func menuBarTitle(isEnabled: Bool) -> String {
        guard isEnabled, activeUntil != nil else {
            return ""
        }

        return formattedRemainingTime()
    }

    private func formattedRemainingTime() -> String {
        let seconds = remainingSeconds
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let remainingSeconds = seconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, remainingSeconds)
        }

        return String(format: "%02d:%02d", minutes, remainingSeconds)
    }

    private func statusImage(isEnabled: Bool) -> NSImage? {
        let symbolName = isEnabled ? "cup.and.saucer.fill" : "cup.and.saucer"
        let configuration = NSImage.SymbolConfiguration(pointSize: 16, weight: .regular)
        let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "保持亮屏")?
            .withSymbolConfiguration(configuration)
        image?.isTemplate = true
        return image
    }

    @objc private func showAbout() {
        let alert = NSAlert()
        alert.messageText = "保持亮屏 1.3.0"
        alert.informativeText = "一个原生 macOS 菜单栏工具。开启后会阻止屏幕因闲置而自动变暗或息屏，支持偏好设置、默认启动状态、电池保护、定时关闭、菜单栏倒计时、系统通知、开机自启动和更新检查。"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "好")
        alert.runModal()
    }

    private func showAssertionError() {
        let alert = NSAlert()
        alert.messageText = "无法开启保持亮屏"
        alert.informativeText = assertion.lastError ?? "系统没有接受本次亮屏请求。"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "好")
        alert.runModal()
    }

    private func showLoginItemError(_ error: Error) {
        let alert = NSAlert()
        alert.messageText = "无法更新开机自启动"
        alert.informativeText = "macOS 没有接受本次登录项设置。你可以将应用移动到“应用程序”文件夹后重试。\n\n\(error.localizedDescription)"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "好")
        alert.runModal()
    }

    private func showBatteryProtectionAlert(_ state: BatteryState) {
        let alert = NSAlert()
        alert.messageText = "电池保护已阻止保持亮屏"
        let chargeText = state.chargePercent.map { "\($0)%" } ?? "当前"
        alert.informativeText = "电量 \(chargeText)，低于 \(AppPreferences.batteryProtectionThreshold)% 阈值。你可以连接电源，或在偏好设置中调整电池保护。"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "好")
        alert.runModal()
    }
}
