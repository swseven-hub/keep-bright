import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let assertion = DisplaySleepAssertion()
    private let notifier = NotificationManager()
    private let updateChecker = UpdateChecker()
    private let batteryMonitor = BatteryMonitor()
    private let hotKeyManager = GlobalHotKeyManager()

    private var statusItem: NSStatusItem?
    private let statusItemLabel = NSMenuItem()
    private let toggleItem = NSMenuItem()
    private let durationMenu = NSMenu()
    private let extend15Item = NSMenuItem()
    private let extend30Item = NSMenuItem()
    private let restartTimerItem = NSMenuItem()
    private let launchAtLoginItem = NSMenuItem()
    private let checkForUpdatesItem = NSMenuItem()
    private let preferencesItem = NSMenuItem()
    private var preferencesWindowController: PreferencesWindowController?

    private var selectedDuration = AwakeDuration.saved
    private var activeUntil: Date?
    private var countdownTimer: Timer?
    private var wasDisabledByBatteryProtection = false
    private var didSendLowBatteryNotification = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        configureBatteryProtection()
        configureGlobalHotKey()
        configureMenuBarItem()

        if AppPreferences.enableOnLaunch {
            setKeepBrightEnabled(true, notify: false)
        } else {
            updateMenuState()
        }

        showFirstLaunchGuideIfNeeded()
        checkForUpdatesAutomaticallyIfNeeded()
    }

    func applicationWillTerminate(_ notification: Notification) {
        countdownTimer?.invalidate()
        batteryMonitor.stop()
        hotKeyManager.unregister()
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

        durationMenu.addItem(.separator())

        let editCustomDurationItem = NSMenuItem(
            title: "编辑自定义时长...",
            action: #selector(showPreferences),
            keyEquivalent: ""
        )
        editCustomDurationItem.target = self
        durationMenu.addItem(editCustomDurationItem)

        durationMenu.addItem(.separator())

        extend15Item.title = "延长 15 分钟"
        extend15Item.target = self
        extend15Item.action = #selector(extendTimerBy15Minutes)
        durationMenu.addItem(extend15Item)

        extend30Item.title = "延长 30 分钟"
        extend30Item.target = self
        extend30Item.action = #selector(extendTimerBy30Minutes)
        durationMenu.addItem(extend30Item)

        restartTimerItem.title = "重新开始计时"
        restartTimerItem.target = self
        restartTimerItem.action = #selector(restartTimer)
        durationMenu.addItem(restartTimerItem)
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
            sendTimerNotification(
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
            sendStatusNotification(
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

    @objc private func extendTimerBy15Minutes() {
        extendTimer(by: 15 * 60, label: "15 分钟")
    }

    @objc private func extendTimerBy30Minutes() {
        extendTimer(by: 30 * 60, label: "30 分钟")
    }

    @objc private func restartTimer() {
        guard assertion.isActive, selectedDuration.seconds != nil else {
            return
        }

        startTimedSession(for: selectedDuration)
        sendTimerNotification(
            title: "计时已重新开始",
            body: selectedDuration.notificationBody
        )
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

            guard assertion.enable(mode: AppPreferences.sleepPreventionMode) else {
                stopCountdown()
                updateMenuState()
                showAssertionError()
                return
            }

            wasDisabledByBatteryProtection = false
            startTimedSession(for: selectedDuration)

            if notify {
                sendStatusNotification(
                    title: "保持亮屏已开启",
                    body: selectedDuration.notificationBody
                )
            }
        } else {
            stopCountdown()
            assertion.disable()
            wasDisabledByBatteryProtection = false

            if notify {
                sendStatusNotification(
                    title: "保持亮屏已关闭",
                    body: "屏幕将恢复系统默认节能策略。"
                )
            }
        }

        updateMenuState()
    }

    private func configureGlobalHotKey() {
        if AppPreferences.globalHotKeyEnabled {
            hotKeyManager.register { [weak self] in
                DispatchQueue.main.async {
                    self?.toggleKeepBright()
                }
            }
        } else {
            hotKeyManager.unregister()
        }
    }

    private func configureBatteryProtection() {
        batteryMonitor.onStateEvaluated = { [weak self] state in
            DispatchQueue.main.async {
                self?.handleBatteryState(state)
            }
        }
        batteryMonitor.start()
    }

    private func preferencesDidChange() {
        configureDurationMenu()
        configureGlobalHotKey()

        if AppPreferences.batteryProtectionMode != .autoDisable {
            wasDisabledByBatteryProtection = false
        }

        if assertion.isActive {
            guard assertion.enable(mode: AppPreferences.sleepPreventionMode) else {
                stopCountdown()
                updateMenuState()
                showAssertionError()
                return
            }
        }

        if selectedDuration == .custom, assertion.isActive {
            startTimedSession(for: selectedDuration)
        }

        if let state = batteryMonitor.shouldPreventEnabling(), assertion.isActive {
            applyBatteryProtection(state, shouldRestoreWhenConnected: true)
        }

        updateMenuState()
    }

    private func handleBatteryState(_ state: BatteryState) {
        let isBelowThreshold = state.isBelowOrEqual(to: AppPreferences.batteryProtectionThreshold)

        if state.isConnectedToPower {
            didSendLowBatteryNotification = false

            if wasDisabledByBatteryProtection, AppPreferences.restoreAfterPowerConnected {
                wasDisabledByBatteryProtection = false
                setKeepBrightEnabled(true, notify: true)
                sendStatusNotification(
                    title: "已连接电源",
                    body: "Keep Bright 已恢复保持亮屏。"
                )
            }
            return
        }

        if !isBelowThreshold {
            didSendLowBatteryNotification = false
            return
        }

        switch AppPreferences.batteryProtectionMode {
        case .off:
            return
        case .notifyOnly:
            notifyLowBatteryOnce(state)
        case .autoDisable:
            applyBatteryProtection(state, shouldRestoreWhenConnected: AppPreferences.restoreAfterPowerConnected)
        }
    }

    private func notifyLowBatteryOnce(_ state: BatteryState) {
        guard assertion.isActive, !didSendLowBatteryNotification else {
            return
        }

        didSendLowBatteryNotification = true
        let chargeText = state.chargePercent.map { "\($0)%" } ?? "当前"
        sendBatteryNotification(
            title: "电量较低",
            body: "电量 \(chargeText)，已低于 \(AppPreferences.batteryProtectionThreshold)% 阈值。保持亮屏仍在运行。"
        )
    }

    private func applyBatteryProtection(_ state: BatteryState, shouldRestoreWhenConnected: Bool) {
        guard assertion.isActive else {
            return
        }

        stopCountdown()
        assertion.disable()
        wasDisabledByBatteryProtection = shouldRestoreWhenConnected
        didSendLowBatteryNotification = true
        updateMenuState()

        let chargeText = state.chargePercent.map { "\($0)%" } ?? "当前"
        sendBatteryNotification(
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
            sendTimerNotification(
                title: "定时保持亮屏已结束",
                body: "屏幕已恢复系统默认节能策略。"
            )
            return
        }

        updateMenuState()
    }

    private func extendTimer(by seconds: TimeInterval, label: String) {
        guard assertion.isActive else {
            return
        }

        if activeUntil == nil {
            activeUntil = Date()
            let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
                self?.tickCountdown()
            }
            RunLoop.main.add(timer, forMode: .common)
            countdownTimer = timer
        }

        activeUntil = max(activeUntil ?? Date(), Date()).addingTimeInterval(seconds)
        updateMenuState()
        sendTimerNotification(
            title: "已延长保持亮屏",
            body: "本次计时已延长 \(label)，剩余 \(formattedRemainingTime())。"
        )
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

        let hasTimer = isEnabled && activeUntil != nil
        extend15Item.isEnabled = isEnabled
        extend30Item.isEnabled = isEnabled
        restartTimerItem.isEnabled = hasTimer && selectedDuration.seconds != nil

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
        guard AppPreferences.automaticUpdateChecksEnabled else {
            return
        }

        updateChecker.checkAutomatically { [weak self] result in
            self?.handleUpdateCheckResult(result, isAutomatic: true)
        }
    }

    private func showFirstLaunchGuideIfNeeded() {
        guard !AppPreferences.hasSeenFirstLaunchGuide else {
            return
        }

        AppPreferences.hasSeenFirstLaunchGuide = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            self?.showFirstLaunchGuide()
        }
    }

    private func showFirstLaunchGuide() {
        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.messageText = "Keep Bright 已在菜单栏运行"
        alert.informativeText = "点击屏幕顶部菜单栏里的杯子图标，可以开启或关闭保持亮屏、设置保持时长、打开偏好设置。"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "开始使用")
        alert.addButton(withTitle: "打开偏好设置")

        if alert.runModal() == .alertSecondButtonReturn {
            showPreferences()
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

        return "保持亮屏：已开启（\(AppPreferences.sleepPreventionMode.shortTitle)，永久）"
    }

    private func menuBarTitle(isEnabled: Bool) -> String {
        switch AppPreferences.menuBarDisplayMode {
        case .iconOnly:
            return ""
        case .remainingTime:
            guard isEnabled, activeUntil != nil else {
                return ""
            }
            return formattedRemainingTime()
        case .preventionMode:
            guard isEnabled else {
                return ""
            }
            return AppPreferences.sleepPreventionMode.shortTitle
        case .statusText:
            guard isEnabled else {
                return "已关闭"
            }
            if activeUntil != nil {
                return "剩余 \(formattedRemainingTime())"
            }
            return "已开启"
        }
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

    private func sendStatusNotification(title: String, body: String) {
        guard AppPreferences.notifyStatusChanges else {
            return
        }

        notifier.send(title: title, body: body)
    }

    private func sendTimerNotification(title: String, body: String) {
        guard AppPreferences.notifyTimerEvents else {
            return
        }

        notifier.send(title: title, body: body)
    }

    private func sendBatteryNotification(title: String, body: String) {
        guard AppPreferences.notifyBatteryEvents else {
            return
        }

        notifier.send(title: title, body: body)
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
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.6.2"
        alert.messageText = "保持亮屏 \(version)"
        alert.informativeText = "一个原生 macOS 菜单栏工具。开启后会阻止屏幕因闲置而自动变暗或息屏，支持全局快捷键、菜单栏显示模式、快速延长时间、通知偏好、Liquid Glass 偏好设置、Universal Binary、DMG 安装包和更新检查。"
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
