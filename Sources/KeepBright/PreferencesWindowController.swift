import AppKit

final class PreferencesWindowController: NSWindowController {
    var onPreferencesChanged: (() -> Void)?

    private let sleepModePopup = NSPopUpButton()
    private let menuBarDisplayPopup = NSPopUpButton()
    private let launchCheckbox = NSButton(checkboxWithTitle: "启动后自动开启保持亮屏", target: nil, action: nil)
    private let hotKeyCheckbox = NSButton(checkboxWithTitle: "启用全局快捷键（Option-Command-K）", target: nil, action: nil)
    private let updateChecksCheckbox = NSButton(checkboxWithTitle: "每天自动检查更新", target: nil, action: nil)
    private let notifyStatusCheckbox = NSButton(checkboxWithTitle: "开启、关闭和恢复状态通知", target: nil, action: nil)
    private let notifyTimerCheckbox = NSButton(checkboxWithTitle: "计时、延长和定时结束通知", target: nil, action: nil)
    private let notifyBatteryCheckbox = NSButton(checkboxWithTitle: "低电量和电池保护通知", target: nil, action: nil)
    private let batteryProtectionPopup = NSPopUpButton()
    private let restoreAfterPowerCheckbox = NSButton(checkboxWithTitle: "连接电源后自动恢复保持亮屏", target: nil, action: nil)
    private let customDurationStepper = NSStepper()
    private let customDurationField = NSTextField()
    private let thresholdSlider = NSSlider(value: 20, minValue: 5, maxValue: 80, target: nil, action: nil)
    private let thresholdValueLabel = NSTextField(labelWithString: "20%")

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 420),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "偏好设置"
        window.isReleasedWhenClosed = false
        window.center()

        super.init(window: window)
        configureControls()
        configureContent()
        syncControls()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show() {
        syncControls()
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func configureControls() {
        configureSleepModePopup()
        configureMenuBarDisplayPopup()
        configureBatteryProtectionPopup()

        launchCheckbox.target = self
        launchCheckbox.action = #selector(toggleLaunchPreference)

        hotKeyCheckbox.target = self
        hotKeyCheckbox.action = #selector(toggleHotKey)

        updateChecksCheckbox.target = self
        updateChecksCheckbox.action = #selector(toggleUpdateChecks)

        notifyStatusCheckbox.target = self
        notifyStatusCheckbox.action = #selector(toggleStatusNotifications)

        notifyTimerCheckbox.target = self
        notifyTimerCheckbox.action = #selector(toggleTimerNotifications)

        notifyBatteryCheckbox.target = self
        notifyBatteryCheckbox.action = #selector(toggleBatteryNotifications)

        restoreAfterPowerCheckbox.target = self
        restoreAfterPowerCheckbox.action = #selector(toggleRestoreAfterPower)

        customDurationField.alignment = .right
        customDurationField.font = .monospacedDigitSystemFont(ofSize: 13, weight: .regular)
        customDurationField.widthAnchor.constraint(equalToConstant: 58).isActive = true
        customDurationField.target = self
        customDurationField.action = #selector(changeCustomDurationFromField)

        customDurationStepper.minValue = 1
        customDurationStepper.maxValue = 720
        customDurationStepper.increment = 5
        customDurationStepper.target = self
        customDurationStepper.action = #selector(changeCustomDurationFromStepper)

        thresholdSlider.target = self
        thresholdSlider.action = #selector(changeBatteryThreshold)
        thresholdSlider.numberOfTickMarks = 16
        thresholdSlider.allowsTickMarkValuesOnly = false
        thresholdSlider.controlSize = .regular
        thresholdSlider.widthAnchor.constraint(equalToConstant: 250).isActive = true

        thresholdValueLabel.font = .monospacedDigitSystemFont(ofSize: 13, weight: .regular)
        thresholdValueLabel.alignment = .right
        thresholdValueLabel.widthAnchor.constraint(equalToConstant: 42).isActive = true
    }

    private func configureContent() {
        guard let contentView = window?.contentView else {
            return
        }

        let tabView = NSTabView()
        tabView.translatesAutoresizingMaskIntoConstraints = false
        tabView.addTabViewItem(tab(label: "常规", view: generalView()))
        tabView.addTabViewItem(tab(label: "计时", view: timerView()))
        tabView.addTabViewItem(tab(label: "电池", view: batteryView()))
        tabView.addTabViewItem(tab(label: "更新", view: updatesView()))
        tabView.addTabViewItem(tab(label: "通知", view: notificationsView()))
        tabView.addTabViewItem(tab(label: "关于", view: aboutView()))

        contentView.addSubview(tabView)
        NSLayoutConstraint.activate([
            tabView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 18),
            tabView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -18),
            tabView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 18),
            tabView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -18)
        ])
    }

    private func generalView() -> NSView {
        let stack = pageStack(title: "常规")
        stack.addArrangedSubview(labeledRow(title: "防睡眠模式", control: sleepModePopup))
        stack.addArrangedSubview(labeledRow(title: "菜单栏显示", control: menuBarDisplayPopup))
        stack.addArrangedSubview(launchCheckbox)
        stack.addArrangedSubview(hotKeyCheckbox)
        stack.addArrangedSubview(infoLabel("全局快捷键可在其他应用中快速开启或关闭 Keep Bright。"))
        return pageView(stack)
    }

    private func timerView() -> NSView {
        let stack = pageStack(title: "计时")
        stack.addArrangedSubview(labeledRow(title: "自定义时长", control: customDurationControl()))
        stack.addArrangedSubview(infoLabel("菜单中的“自定义”会使用这里的分钟数。定时运行时可在菜单里快速延长 15 或 30 分钟。"))
        return pageView(stack)
    }

    private func batteryView() -> NSView {
        let stack = pageStack(title: "电池")
        stack.addArrangedSubview(labeledRow(title: "低电量保护", control: batteryProtectionPopup))
        stack.addArrangedSubview(labeledRow(title: "电量阈值", control: thresholdControl()))
        stack.addArrangedSubview(restoreAfterPowerCheckbox)
        stack.addArrangedSubview(infoLabel("电池保护只在使用电池供电时触发，连接电源时不会自动关闭。"))
        return pageView(stack)
    }

    private func updatesView() -> NSView {
        let stack = pageStack(title: "更新")
        stack.addArrangedSubview(updateChecksCheckbox)
        stack.addArrangedSubview(infoLabel("开启后，Keep Bright 每天最多访问一次 GitHub Releases 检查新版本。手动检查更新始终可用。"))
        return pageView(stack)
    }

    private func notificationsView() -> NSView {
        let stack = pageStack(title: "通知")
        stack.addArrangedSubview(notifyStatusCheckbox)
        stack.addArrangedSubview(notifyTimerCheckbox)
        stack.addArrangedSubview(notifyBatteryCheckbox)
        stack.addArrangedSubview(infoLabel("如果 macOS 隐藏通知预览，系统可能只显示“收到一条通知”。这需要在系统设置中调整。"))
        return pageView(stack)
    }

    private func aboutView() -> NSView {
        let stack = pageStack(title: "Keep Bright")
        stack.addArrangedSubview(infoLabel("原生 macOS 菜单栏保持亮屏工具。当前构建为 Universal Binary。"))

        let githubButton = NSButton(title: "打开 GitHub", target: self, action: #selector(openGitHub))
        let privacyButton = NSButton(title: "查看隐私说明", target: self, action: #selector(openPrivacy))
        let row = NSStackView(views: [githubButton, privacyButton])
        row.orientation = .horizontal
        row.spacing = 10
        stack.addArrangedSubview(row)
        return pageView(stack)
    }

    private func pageStack(title: String) -> NSStackView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .systemFont(ofSize: 20, weight: .semibold)
        stack.addArrangedSubview(titleLabel)
        return stack
    }

    private func pageView(_ stack: NSStackView) -> NSView {
        let view = NSView()
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -20),
            stack.topAnchor.constraint(equalTo: view.topAnchor, constant: 20)
        ])
        return view
    }

    private func tab(label: String, view: NSView) -> NSTabViewItem {
        let item = NSTabViewItem(identifier: label)
        item.label = label
        item.view = view
        return item
    }

    private func customDurationControl() -> NSStackView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 8
        row.addArrangedSubview(customDurationField)
        row.addArrangedSubview(NSTextField(labelWithString: "分钟"))
        row.addArrangedSubview(customDurationStepper)
        return row
    }

    private func thresholdControl() -> NSStackView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 8
        row.addArrangedSubview(thresholdSlider)
        row.addArrangedSubview(thresholdValueLabel)
        return row
    }

    private func infoLabel(_ text: String) -> NSTextField {
        let label = NSTextField(wrappingLabelWithString: text)
        label.textColor = .secondaryLabelColor
        label.font = .systemFont(ofSize: 12)
        label.maximumNumberOfLines = 3
        label.widthAnchor.constraint(lessThanOrEqualToConstant: 430).isActive = true
        return label
    }

    private func labeledRow(title: String, control: NSView) -> NSStackView {
        let label = NSTextField(labelWithString: title)
        label.alignment = .right
        label.widthAnchor.constraint(equalToConstant: 92).isActive = true

        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 10
        row.addArrangedSubview(label)
        row.addArrangedSubview(control)
        return row
    }

    private func syncControls() {
        selectPopupItem(sleepModePopup, rawValue: AppPreferences.sleepPreventionMode.rawValue)
        selectPopupItem(menuBarDisplayPopup, rawValue: AppPreferences.menuBarDisplayMode.rawValue)
        launchCheckbox.state = AppPreferences.enableOnLaunch ? .on : .off
        hotKeyCheckbox.state = AppPreferences.globalHotKeyEnabled ? .on : .off
        updateChecksCheckbox.state = AppPreferences.automaticUpdateChecksEnabled ? .on : .off
        notifyStatusCheckbox.state = AppPreferences.notifyStatusChanges ? .on : .off
        notifyTimerCheckbox.state = AppPreferences.notifyTimerEvents ? .on : .off
        notifyBatteryCheckbox.state = AppPreferences.notifyBatteryEvents ? .on : .off
        customDurationField.integerValue = AppPreferences.customDurationMinutes
        customDurationStepper.integerValue = AppPreferences.customDurationMinutes
        selectPopupItem(batteryProtectionPopup, rawValue: AppPreferences.batteryProtectionMode.rawValue)
        restoreAfterPowerCheckbox.state = AppPreferences.restoreAfterPowerConnected ? .on : .off
        thresholdSlider.integerValue = AppPreferences.batteryProtectionThreshold
        updateThresholdLabel()
        updateBatteryControls()
    }

    private func configureSleepModePopup() {
        sleepModePopup.removeAllItems()
        for mode in SleepPreventionMode.allCases {
            sleepModePopup.addItem(withTitle: mode.title)
            sleepModePopup.lastItem?.representedObject = mode.rawValue
        }
        sleepModePopup.target = self
        sleepModePopup.action = #selector(changeSleepMode)
        sleepModePopup.widthAnchor.constraint(equalToConstant: 300).isActive = true
    }

    private func configureMenuBarDisplayPopup() {
        menuBarDisplayPopup.removeAllItems()
        for mode in MenuBarDisplayMode.allCases {
            menuBarDisplayPopup.addItem(withTitle: mode.title)
            menuBarDisplayPopup.lastItem?.representedObject = mode.rawValue
        }
        menuBarDisplayPopup.target = self
        menuBarDisplayPopup.action = #selector(changeMenuBarDisplayMode)
        menuBarDisplayPopup.widthAnchor.constraint(equalToConstant: 300).isActive = true
    }

    private func configureBatteryProtectionPopup() {
        batteryProtectionPopup.removeAllItems()
        for mode in BatteryProtectionMode.allCases {
            batteryProtectionPopup.addItem(withTitle: mode.title)
            batteryProtectionPopup.lastItem?.representedObject = mode.rawValue
        }
        batteryProtectionPopup.target = self
        batteryProtectionPopup.action = #selector(changeBatteryProtectionMode)
        batteryProtectionPopup.widthAnchor.constraint(equalToConstant: 300).isActive = true
    }

    private func selectPopupItem(_ popup: NSPopUpButton, rawValue: Int) {
        for item in popup.itemArray where item.representedObject as? Int == rawValue {
            popup.select(item)
            return
        }
    }

    @objc private func changeSleepMode() {
        guard let rawValue = sleepModePopup.selectedItem?.representedObject as? Int,
              let mode = SleepPreventionMode(rawValue: rawValue) else {
            return
        }

        AppPreferences.sleepPreventionMode = mode
        onPreferencesChanged?()
    }

    @objc private func changeMenuBarDisplayMode() {
        guard let rawValue = menuBarDisplayPopup.selectedItem?.representedObject as? Int,
              let mode = MenuBarDisplayMode(rawValue: rawValue) else {
            return
        }

        AppPreferences.menuBarDisplayMode = mode
        onPreferencesChanged?()
    }

    @objc private func toggleLaunchPreference() {
        AppPreferences.enableOnLaunch = launchCheckbox.state == .on
        onPreferencesChanged?()
    }

    @objc private func toggleHotKey() {
        AppPreferences.globalHotKeyEnabled = hotKeyCheckbox.state == .on
        onPreferencesChanged?()
    }

    @objc private func toggleUpdateChecks() {
        AppPreferences.automaticUpdateChecksEnabled = updateChecksCheckbox.state == .on
        onPreferencesChanged?()
    }

    @objc private func toggleStatusNotifications() {
        AppPreferences.notifyStatusChanges = notifyStatusCheckbox.state == .on
        onPreferencesChanged?()
    }

    @objc private func toggleTimerNotifications() {
        AppPreferences.notifyTimerEvents = notifyTimerCheckbox.state == .on
        onPreferencesChanged?()
    }

    @objc private func toggleBatteryNotifications() {
        AppPreferences.notifyBatteryEvents = notifyBatteryCheckbox.state == .on
        onPreferencesChanged?()
    }

    @objc private func changeBatteryProtectionMode() {
        guard let rawValue = batteryProtectionPopup.selectedItem?.representedObject as? Int,
              let mode = BatteryProtectionMode(rawValue: rawValue) else {
            return
        }

        AppPreferences.batteryProtectionMode = mode
        updateBatteryControls()
        onPreferencesChanged?()
    }

    @objc private func toggleRestoreAfterPower() {
        AppPreferences.restoreAfterPowerConnected = restoreAfterPowerCheckbox.state == .on
        onPreferencesChanged?()
    }

    @objc private func changeBatteryThreshold() {
        AppPreferences.batteryProtectionThreshold = thresholdSlider.integerValue
        thresholdSlider.integerValue = AppPreferences.batteryProtectionThreshold
        updateThresholdLabel()
        onPreferencesChanged?()
    }

    @objc private func changeCustomDurationFromField() {
        AppPreferences.customDurationMinutes = customDurationField.integerValue
        syncCustomDurationControls()
        onPreferencesChanged?()
    }

    @objc private func changeCustomDurationFromStepper() {
        AppPreferences.customDurationMinutes = customDurationStepper.integerValue
        syncCustomDurationControls()
        onPreferencesChanged?()
    }

    @objc private func openGitHub() {
        if let url = URL(string: "https://github.com/swseven-hub/keep-bright") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func openPrivacy() {
        if let url = URL(string: "https://github.com/swseven-hub/keep-bright/blob/main/PRIVACY.md") {
            NSWorkspace.shared.open(url)
        }
    }

    private func syncCustomDurationControls() {
        customDurationField.integerValue = AppPreferences.customDurationMinutes
        customDurationStepper.integerValue = AppPreferences.customDurationMinutes
    }

    private func updateThresholdLabel() {
        thresholdValueLabel.stringValue = "\(AppPreferences.batteryProtectionThreshold)%"
    }

    private func updateBatteryControls() {
        let isEnabled = AppPreferences.batteryProtectionMode != .off
        thresholdSlider.isEnabled = isEnabled
        restoreAfterPowerCheckbox.isEnabled = AppPreferences.batteryProtectionMode == .autoDisable
        thresholdValueLabel.textColor = isEnabled ? .labelColor : .secondaryLabelColor
    }
}
