import AppKit

final class PreferencesWindowController: NSWindowController {
    var onPreferencesChanged: (() -> Void)?

    private let launchCheckbox = NSButton(checkboxWithTitle: "启动后自动开启保持亮屏", target: nil, action: nil)
    private let batteryProtectionCheckbox = NSButton(checkboxWithTitle: "低电量时自动关闭保持亮屏", target: nil, action: nil)
    private let thresholdSlider = NSSlider(value: 20, minValue: 5, maxValue: 80, target: nil, action: nil)
    private let thresholdValueLabel = NSTextField(labelWithString: "20%")

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 230),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "偏好设置"
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

        launchCheckbox.target = self
        launchCheckbox.action = #selector(toggleLaunchPreference)

        batteryProtectionCheckbox.target = self
        batteryProtectionCheckbox.action = #selector(toggleBatteryProtection)

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
        stack.addArrangedSubview(launchCheckbox)
        stack.addArrangedSubview(batteryProtectionCheckbox)
        stack.addArrangedSubview(thresholdRow)

        contentView.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 28),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -28),
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 26)
        ])
    }

    private func syncControls() {
        launchCheckbox.state = AppPreferences.enableOnLaunch ? .on : .off
        batteryProtectionCheckbox.state = AppPreferences.batteryProtectionEnabled ? .on : .off
        thresholdSlider.integerValue = AppPreferences.batteryProtectionThreshold
        updateThresholdLabel()
        updateBatteryControls()
    }

    @objc private func toggleLaunchPreference() {
        AppPreferences.enableOnLaunch = launchCheckbox.state == .on
        onPreferencesChanged?()
    }

    @objc private func toggleBatteryProtection() {
        AppPreferences.batteryProtectionEnabled = batteryProtectionCheckbox.state == .on
        updateBatteryControls()
        onPreferencesChanged?()
    }

    @objc private func changeBatteryThreshold() {
        AppPreferences.batteryProtectionThreshold = thresholdSlider.integerValue
        thresholdSlider.integerValue = AppPreferences.batteryProtectionThreshold
        updateThresholdLabel()
        onPreferencesChanged?()
    }

    private func updateThresholdLabel() {
        thresholdValueLabel.stringValue = "\(AppPreferences.batteryProtectionThreshold)%"
    }

    private func updateBatteryControls() {
        let isEnabled = AppPreferences.batteryProtectionEnabled
        thresholdSlider.isEnabled = isEnabled
        thresholdValueLabel.textColor = isEnabled ? .labelColor : .secondaryLabelColor
    }
}
