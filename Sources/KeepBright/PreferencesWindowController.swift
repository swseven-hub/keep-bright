import AppKit

final class PreferencesWindowController: NSWindowController {
    var onPreferencesChanged: (() -> Void)?

    private let sleepModePopup = NSPopUpButton()
    private let launchCheckbox = NSButton(checkboxWithTitle: "启动后自动开启保持亮屏", target: nil, action: nil)
    private let updateChecksCheckbox = NSButton(checkboxWithTitle: "每天自动检查更新", target: nil, action: nil)
    private let batteryProtectionPopup = NSPopUpButton()
    private let restoreAfterPowerCheckbox = NSButton(checkboxWithTitle: "连接电源后自动恢复保持亮屏", target: nil, action: nil)
    private let customDurationStepper = NSStepper()
    private let customDurationField = NSTextField()
    private let thresholdSlider = NSSlider(value: 20, minValue: 5, maxValue: 80, target: nil, action: nil)
    private let thresholdValueLabel = NSTextField(labelWithString: "20%")

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 390),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "偏好设置"
        window.setContentSize(NSSize(width: 500, height: 390))
        window.isReleasedWhenClosed = false
        window.center()

        super.init(window: window)
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

    private func configureContent() {
        guard let contentView = window?.contentView else {
            return
        }

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 18
        stack.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = NSTextField(labelWithString: "Keep Bright")
        titleLabel.font = .systemFont(ofSize: 20, weight: .semibold)

        configureSleepModePopup()
        configureBatteryProtectionPopup()

        let sleepModeRow = labeledRow(title: "防睡眠模式", control: sleepModePopup)

        launchCheckbox.target = self
        launchCheckbox.action = #selector(toggleLaunchPreference)

        updateChecksCheckbox.target = self
        updateChecksCheckbox.action = #selector(toggleUpdateChecks)

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

        let customDurationRow = NSStackView()
        customDurationRow.orientation = .horizontal
        customDurationRow.alignment = .centerY
        customDurationRow.spacing = 8
        customDurationRow.addArrangedSubview(NSTextField(labelWithString: "自定义保持时长"))
        customDurationRow.addArrangedSubview(customDurationField)
        customDurationRow.addArrangedSubview(NSTextField(labelWithString: "分钟"))
        customDurationRow.addArrangedSubview(customDurationStepper)

        let batteryModeRow = labeledRow(title: "低电量保护", control: batteryProtectionPopup)

        thresholdSlider.target = self
        thresholdSlider.action = #selector(changeBatteryThreshold)
        thresholdSlider.numberOfTickMarks = 16
        thresholdSlider.allowsTickMarkValuesOnly = false
        thresholdSlider.controlSize = .regular
        thresholdSlider.widthAnchor.constraint(equalToConstant: 230).isActive = true

        thresholdValueLabel.font = .monospacedDigitSystemFont(ofSize: 13, weight: .regular)
        thresholdValueLabel.alignment = .right
        thresholdValueLabel.widthAnchor.constraint(equalToConstant: 42).isActive = true

        let thresholdRow = NSStackView()
        thresholdRow.orientation = .horizontal
        thresholdRow.alignment = .centerY
        thresholdRow.spacing = 8
        thresholdRow.addArrangedSubview(NSTextField(labelWithString: "电量阈值"))
        thresholdRow.addArrangedSubview(thresholdSlider)
        thresholdRow.addArrangedSubview(thresholdValueLabel)

        stack.addArrangedSubview(titleLabel)
        stack.addArrangedSubview(sleepModeRow)
        stack.addArrangedSubview(launchCheckbox)
        stack.addArrangedSubview(updateChecksCheckbox)
        stack.addArrangedSubview(customDurationRow)
        stack.addArrangedSubview(batteryModeRow)
        stack.addArrangedSubview(thresholdRow)
        stack.addArrangedSubview(restoreAfterPowerCheckbox)

        contentView.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 28),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -28),
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 26)
        ])
    }

    private func syncControls() {
        selectPopupItem(sleepModePopup, rawValue: AppPreferences.sleepPreventionMode.rawValue)
        launchCheckbox.state = AppPreferences.enableOnLaunch ? .on : .off
        updateChecksCheckbox.state = AppPreferences.automaticUpdateChecksEnabled ? .on : .off
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
        sleepModePopup.widthAnchor.constraint(equalToConstant: 250).isActive = true
    }

    private func configureBatteryProtectionPopup() {
        batteryProtectionPopup.removeAllItems()
        for mode in BatteryProtectionMode.allCases {
            batteryProtectionPopup.addItem(withTitle: mode.title)
            batteryProtectionPopup.lastItem?.representedObject = mode.rawValue
        }
        batteryProtectionPopup.target = self
        batteryProtectionPopup.action = #selector(changeBatteryProtectionMode)
        batteryProtectionPopup.widthAnchor.constraint(equalToConstant: 250).isActive = true
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

    @objc private func toggleLaunchPreference() {
        AppPreferences.enableOnLaunch = launchCheckbox.state == .on
        onPreferencesChanged?()
    }

    @objc private func toggleUpdateChecks() {
        AppPreferences.automaticUpdateChecksEnabled = updateChecksCheckbox.state == .on
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
