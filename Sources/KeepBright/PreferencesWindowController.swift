import AppKit

final class PreferencesWindowController: NSWindowController, NSTableViewDataSource, NSTableViewDelegate {
    var onPreferencesChanged: (() -> Void)?

    fileprivate enum Pane: Int, CaseIterable {
        case general
        case timer
        case battery
        case updates
        case notifications
        case about

        var title: String {
            switch self {
            case .general:
                return "常规"
            case .timer:
                return "计时"
            case .battery:
                return "电池"
            case .updates:
                return "更新"
            case .notifications:
                return "通知"
            case .about:
                return "关于"
            }
        }

        var subtitle: String {
            switch self {
            case .general:
                return "控制 Keep Bright 的默认行为、菜单栏呈现和快捷入口。"
            case .timer:
                return "设置定时保持亮屏的默认时长，并配合菜单中的快速延长操作。"
            case .battery:
                return "在使用电池供电时保护电量，避免长时间亮屏造成意外耗电。"
            case .updates:
                return "通过 GitHub Releases 检查新版本，保持安装包和说明文档同步。"
            case .notifications:
                return "分别控制状态、计时和电池保护通知，让提醒保持克制。"
            case .about:
                return "Keep Bright 是一个原生 macOS 菜单栏保持亮屏工具。"
            }
        }

        var symbolName: String {
            switch self {
            case .general:
                return "sun.max"
            case .timer:
                return "timer"
            case .battery:
                return "battery.50"
            case .updates:
                return "arrow.triangle.2.circlepath"
            case .notifications:
                return "bell"
            case .about:
                return "info.circle"
            }
        }
    }

    private let panes = Pane.allCases
    private var selectedPane: Pane = .general

    private let sidebarTable = NSTableView()
    private let pageTitleLabel = NSTextField(labelWithString: "")
    private let pageSubtitleLabel = NSTextField(wrappingLabelWithString: "")
    private let detailStack = NSStackView()
    private let detailDocumentView = NSView()

    private let sleepModePopup = NSPopUpButton()
    private let menuBarDisplayPopup = NSPopUpButton()
    private let launchSwitch = NSSwitch()
    private let hotKeySwitch = NSSwitch()
    private let updateChecksSwitch = NSSwitch()
    private let notifyStatusSwitch = NSSwitch()
    private let notifyTimerSwitch = NSSwitch()
    private let notifyBatterySwitch = NSSwitch()
    private let batteryProtectionPopup = NSPopUpButton()
    private let restoreAfterPowerSwitch = NSSwitch()
    private let customDurationStepper = NSStepper()
    private let customDurationField = NSTextField()
    private let thresholdSlider = NSSlider(value: 20, minValue: 5, maxValue: 80, target: nil, action: nil)
    private let thresholdValueLabel = NSTextField(labelWithString: "20%")

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 780, height: 560),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Keep Bright"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 720, height: 500)
        window.center()

        super.init(window: window)
        configureControls()
        configureContent()
        syncControls()
        selectPane(.general)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show() {
        syncControls()
        renderSelectedPane()
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func configureControls() {
        configureSleepModePopup()
        configureMenuBarDisplayPopup()
        configureBatteryProtectionPopup()

        configureSwitch(launchSwitch, action: #selector(toggleLaunchPreference))
        configureSwitch(hotKeySwitch, action: #selector(toggleHotKey))
        configureSwitch(updateChecksSwitch, action: #selector(toggleUpdateChecks))
        configureSwitch(notifyStatusSwitch, action: #selector(toggleStatusNotifications))
        configureSwitch(notifyTimerSwitch, action: #selector(toggleTimerNotifications))
        configureSwitch(notifyBatterySwitch, action: #selector(toggleBatteryNotifications))
        configureSwitch(restoreAfterPowerSwitch, action: #selector(toggleRestoreAfterPower))

        customDurationField.alignment = .right
        customDurationField.font = .monospacedDigitSystemFont(ofSize: 13, weight: .regular)
        customDurationField.controlSize = .regular
        customDurationField.bezelStyle = .roundedBezel
        customDurationField.widthAnchor.constraint(equalToConstant: 64).isActive = true
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
        thresholdSlider.widthAnchor.constraint(equalToConstant: 260).isActive = true

        thresholdValueLabel.font = .monospacedDigitSystemFont(ofSize: 13, weight: .medium)
        thresholdValueLabel.alignment = .right
        thresholdValueLabel.widthAnchor.constraint(equalToConstant: 44).isActive = true
    }

    private func configureContent() {
        guard let contentView = window?.contentView else {
            return
        }

        let splitView = NSSplitView()
        splitView.isVertical = true
        splitView.dividerStyle = .thin
        splitView.translatesAutoresizingMaskIntoConstraints = false

        let sidebarView = makeSidebarView()
        let detailView = makeDetailView()
        splitView.addArrangedSubview(sidebarView)
        splitView.addArrangedSubview(detailView)

        contentView.addSubview(splitView)

        NSLayoutConstraint.activate([
            splitView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            splitView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            splitView.topAnchor.constraint(equalTo: contentView.topAnchor),
            splitView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            sidebarView.widthAnchor.constraint(equalToConstant: 220)
        ])
    }

    private func makeSidebarView() -> NSView {
        let effectView = NSVisualEffectView()
        effectView.material = .sidebar
        effectView.blendingMode = .behindWindow
        effectView.state = .active
        effectView.translatesAutoresizingMaskIntoConstraints = false

        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        effectView.addSubview(container)

        let header = makeSidebarHeader()
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        let column = NSTableColumn(identifier: .preferencesPaneColumn)
        column.resizingMask = .autoresizingMask
        sidebarTable.addTableColumn(column)
        sidebarTable.headerView = nil
        sidebarTable.rowHeight = 38
        sidebarTable.intercellSpacing = NSSize(width: 0, height: 4)
        sidebarTable.style = .sourceList
        sidebarTable.backgroundColor = .clear
        sidebarTable.usesAlternatingRowBackgroundColors = false
        sidebarTable.focusRingType = .none
        sidebarTable.delegate = self
        sidebarTable.dataSource = self
        sidebarTable.reloadData()

        scrollView.documentView = sidebarTable
        container.addSubview(header)
        container.addSubview(scrollView)

        NSLayoutConstraint.activate([
            container.leadingAnchor.constraint(equalTo: effectView.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: effectView.trailingAnchor),
            container.topAnchor.constraint(equalTo: effectView.topAnchor),
            container.bottomAnchor.constraint(equalTo: effectView.bottomAnchor),

            header.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 18),
            header.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -14),
            header.topAnchor.constraint(equalTo: container.topAnchor, constant: 54),

            scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 8),
            scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -8),
            scrollView.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 22),
            scrollView.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -12)
        ])

        return effectView
    }

    private func makeSidebarHeader() -> NSView {
        let header = NSStackView()
        header.orientation = .horizontal
        header.alignment = .centerY
        header.spacing = 10
        header.translatesAutoresizingMaskIntoConstraints = false

        let iconView = NSImageView()
        let configuration = NSImage.SymbolConfiguration(pointSize: 26, weight: .semibold)
        iconView.image = NSImage(systemSymbolName: "cup.and.saucer.fill", accessibilityDescription: nil)?
            .withSymbolConfiguration(configuration)
        iconView.image?.isTemplate = true
        iconView.contentTintColor = .controlAccentColor
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.widthAnchor.constraint(equalToConstant: 32).isActive = true
        iconView.heightAnchor.constraint(equalToConstant: 32).isActive = true

        let titleStack = NSStackView()
        titleStack.orientation = .vertical
        titleStack.alignment = .leading
        titleStack.spacing = 1

        let title = NSTextField(labelWithString: "Keep Bright")
        title.font = .systemFont(ofSize: 14, weight: .semibold)
        title.lineBreakMode = .byTruncatingTail

        let subtitle = NSTextField(labelWithString: "保持亮屏")
        subtitle.font = .systemFont(ofSize: 11, weight: .regular)
        subtitle.textColor = .secondaryLabelColor

        titleStack.addArrangedSubview(title)
        titleStack.addArrangedSubview(subtitle)
        header.addArrangedSubview(iconView)
        header.addArrangedSubview(titleStack)
        return header
    }

    private func makeDetailView() -> NSView {
        let effectView = NSVisualEffectView()
        effectView.material = .contentBackground
        effectView.blendingMode = .behindWindow
        effectView.state = .active
        effectView.translatesAutoresizingMaskIntoConstraints = false

        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        effectView.addSubview(container)

        let headerStack = NSStackView()
        headerStack.orientation = .vertical
        headerStack.alignment = .leading
        headerStack.spacing = 6
        headerStack.translatesAutoresizingMaskIntoConstraints = false

        pageTitleLabel.font = .systemFont(ofSize: 28, weight: .bold)
        pageTitleLabel.textColor = .labelColor
        pageTitleLabel.lineBreakMode = .byTruncatingTail

        pageSubtitleLabel.font = .systemFont(ofSize: 13, weight: .regular)
        pageSubtitleLabel.textColor = .secondaryLabelColor
        pageSubtitleLabel.maximumNumberOfLines = 2

        headerStack.addArrangedSubview(pageTitleLabel)
        headerStack.addArrangedSubview(pageSubtitleLabel)

        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        detailDocumentView.translatesAutoresizingMaskIntoConstraints = false
        detailStack.orientation = .vertical
        detailStack.alignment = .width
        detailStack.spacing = 18
        detailStack.translatesAutoresizingMaskIntoConstraints = false
        detailDocumentView.addSubview(detailStack)
        scrollView.documentView = detailDocumentView

        container.addSubview(headerStack)
        container.addSubview(scrollView)

        NSLayoutConstraint.activate([
            container.leadingAnchor.constraint(equalTo: effectView.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: effectView.trailingAnchor),
            container.topAnchor.constraint(equalTo: effectView.topAnchor),
            container.bottomAnchor.constraint(equalTo: effectView.bottomAnchor),

            headerStack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 34),
            headerStack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -34),
            headerStack.topAnchor.constraint(equalTo: container.topAnchor, constant: 54),

            scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 34),
            scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -30),
            scrollView.topAnchor.constraint(equalTo: headerStack.bottomAnchor, constant: 24),
            scrollView.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -26),

            detailDocumentView.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor),
            detailStack.leadingAnchor.constraint(equalTo: detailDocumentView.leadingAnchor),
            detailStack.trailingAnchor.constraint(equalTo: detailDocumentView.trailingAnchor),
            detailStack.topAnchor.constraint(equalTo: detailDocumentView.topAnchor),
            detailStack.bottomAnchor.constraint(equalTo: detailDocumentView.bottomAnchor)
        ])

        return effectView
    }

    private func selectPane(_ pane: Pane) {
        selectedPane = pane
        sidebarTable.selectRowIndexes(IndexSet(integer: pane.rawValue), byExtendingSelection: false)
        renderSelectedPane()
    }

    private func renderSelectedPane() {
        pageTitleLabel.stringValue = selectedPane.title
        pageSubtitleLabel.stringValue = selectedPane.subtitle

        detailStack.arrangedSubviews.forEach { view in
            detailStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        switch selectedPane {
        case .general:
            renderGeneralPane()
        case .timer:
            renderTimerPane()
        case .battery:
            renderBatteryPane()
        case .updates:
            renderUpdatesPane()
        case .notifications:
            renderNotificationsPane()
        case .about:
            renderAboutPane()
        }
    }

    private func renderGeneralPane() {
        detailStack.addArrangedSubview(section(
            title: "行为",
            rows: [
                settingsRow(
                    title: "防睡眠模式",
                    detail: "默认只阻止屏幕息屏；增强模式会额外防止系统因闲置进入睡眠。",
                    control: sleepModePopup
                ),
                settingsRow(
                    title: "启动后自动开启",
                    detail: "打开 Keep Bright 后立即进入保持亮屏状态。",
                    control: launchSwitch
                )
            ]
        ))

        detailStack.addArrangedSubview(section(
            title: "菜单栏",
            rows: [
                settingsRow(
                    title: "菜单栏显示",
                    detail: "选择杯子图标旁边显示倒计时、防睡眠模式或状态文字。",
                    control: menuBarDisplayPopup
                ),
                settingsRow(
                    title: "全局快捷键",
                    detail: "使用 Option-Command-K 在任意应用中开启或关闭保持亮屏。",
                    control: hotKeySwitch
                )
            ]
        ))
    }

    private func renderTimerPane() {
        detailStack.addArrangedSubview(section(
            title: "默认定时",
            footer: "菜单中的“自定义”会使用这里的分钟数。定时运行时可在菜单里快速延长 15 或 30 分钟。",
            rows: [
                settingsRow(
                    title: "自定义时长",
                    detail: "可设置 1 到 720 分钟。",
                    control: customDurationControl()
                )
            ]
        ))
    }

    private func renderBatteryPane() {
        detailStack.addArrangedSubview(section(
            title: "电池保护",
            footer: "电池保护只在使用电池供电时触发，连接电源时不会自动关闭。",
            rows: [
                settingsRow(
                    title: "低电量保护",
                    detail: "低于阈值后可以只提醒，或自动关闭保持亮屏。",
                    control: batteryProtectionPopup
                ),
                settingsRow(
                    title: "电量阈值",
                    detail: "当电池电量低于或等于该数值时触发保护。",
                    control: thresholdControl()
                ),
                settingsRow(
                    title: "插电后恢复",
                    detail: "如果保持亮屏被电池保护自动关闭，连接电源后自动恢复。",
                    control: restoreAfterPowerSwitch
                )
            ]
        ))
    }

    private func renderUpdatesPane() {
        detailStack.addArrangedSubview(section(
            title: "版本检查",
            footer: "自动检查每天最多访问一次 GitHub Releases。手动检查更新可继续在菜单栏中使用。",
            rows: [
                settingsRow(
                    title: "自动检查更新",
                    detail: "发现新版本时显示原生提示，并引导你打开下载页面。",
                    control: updateChecksSwitch
                ),
                settingsRow(
                    title: "发布页面",
                    detail: "查看历史版本、DMG 安装包和校验信息。",
                    control: actionButton(title: "打开 GitHub", action: #selector(openGitHub))
                )
            ]
        ))
    }

    private func renderNotificationsPane() {
        detailStack.addArrangedSubview(section(
            title: "通知类型",
            rows: [
                settingsRow(
                    title: "状态通知",
                    detail: "开启、关闭和插电恢复保持亮屏时提醒。",
                    control: notifyStatusSwitch
                ),
                settingsRow(
                    title: "计时通知",
                    detail: "保持时长更新、延长计时和定时结束时提醒。",
                    control: notifyTimerSwitch
                ),
                settingsRow(
                    title: "电池通知",
                    detail: "低电量提醒和电池保护自动关闭时提醒。",
                    control: notifyBatterySwitch
                )
            ]
        ))

        detailStack.addArrangedSubview(section(
            title: "系统预览",
            footer: "如果通知只显示“1 个通知”或“收到一条通知”，通常是 macOS 的通知预览隐私设置隐藏了正文。",
            rows: [
                settingsRow(
                    title: "通知设置",
                    detail: "在系统设置里将 Keep Bright 的“显示预览”改为“始终”。",
                    control: actionButton(title: "打开系统设置", action: #selector(openNotificationSettings))
                )
            ]
        ))
    }

    private func renderAboutPane() {
        detailStack.addArrangedSubview(aboutHeader())
        detailStack.addArrangedSubview(section(
            title: "项目",
            rows: [
                settingsRow(
                    title: "源代码",
                    detail: "查看 Keep Bright 的源码、发布包和版本记录。",
                    control: actionButton(title: "打开 GitHub", action: #selector(openGitHub))
                ),
                settingsRow(
                    title: "隐私说明",
                    detail: "Keep Bright 不收集、上传或出售个人数据。",
                    control: actionButton(title: "查看说明", action: #selector(openPrivacy))
                )
            ]
        ))
    }

    private func aboutHeader() -> NSView {
        let card = SettingsGroupView()
        card.translatesAutoresizingMaskIntoConstraints = false

        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false

        let iconView = NSImageView(image: NSImage(named: NSImage.applicationIconName) ?? NSImage())
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.widthAnchor.constraint(equalToConstant: 56).isActive = true
        iconView.heightAnchor.constraint(equalToConstant: 56).isActive = true

        let textStack = NSStackView()
        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = 3

        let title = NSTextField(labelWithString: "Keep Bright")
        title.font = .systemFont(ofSize: 18, weight: .semibold)

        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.6.1"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "8"
        let subtitle = NSTextField(labelWithString: "版本 \(version)（\(build)）")
        subtitle.font = .systemFont(ofSize: 12, weight: .regular)
        subtitle.textColor = .secondaryLabelColor

        let description = NSTextField(wrappingLabelWithString: "一个使用 AppKit、IOKit 和系统通知实现的原生 macOS 菜单栏工具。")
        description.font = .systemFont(ofSize: 12, weight: .regular)
        description.textColor = .secondaryLabelColor
        description.maximumNumberOfLines = 2

        textStack.addArrangedSubview(title)
        textStack.addArrangedSubview(subtitle)
        textStack.addArrangedSubview(description)

        stack.addArrangedSubview(iconView)
        stack.addArrangedSubview(textStack)
        card.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16)
        ])

        return card
    }

    private func section(title: String, footer: String? = nil, rows: [NSView]) -> NSView {
        let container = NSStackView()
        container.orientation = .vertical
        container.alignment = .width
        container.spacing = 8
        container.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        titleLabel.textColor = .secondaryLabelColor
        container.addArrangedSubview(titleLabel)

        let group = SettingsGroupView()
        group.translatesAutoresizingMaskIntoConstraints = false
        let rowStack = NSStackView()
        rowStack.orientation = .vertical
        rowStack.alignment = .width
        rowStack.spacing = 0
        rowStack.translatesAutoresizingMaskIntoConstraints = false
        group.addSubview(rowStack)

        for (index, row) in rows.enumerated() {
            rowStack.addArrangedSubview(row)
            if index < rows.count - 1 {
                rowStack.addArrangedSubview(separator())
            }
        }

        NSLayoutConstraint.activate([
            rowStack.leadingAnchor.constraint(equalTo: group.leadingAnchor),
            rowStack.trailingAnchor.constraint(equalTo: group.trailingAnchor),
            rowStack.topAnchor.constraint(equalTo: group.topAnchor),
            rowStack.bottomAnchor.constraint(equalTo: group.bottomAnchor)
        ])

        container.addArrangedSubview(group)

        if let footer {
            let footerLabel = NSTextField(wrappingLabelWithString: footer)
            footerLabel.font = .systemFont(ofSize: 11, weight: .regular)
            footerLabel.textColor = .tertiaryLabelColor
            footerLabel.maximumNumberOfLines = 3
            container.addArrangedSubview(footerLabel)
        }

        return container
    }

    private func settingsRow(title: String, detail: String, control: NSView) -> NSView {
        let row = NSView()
        row.translatesAutoresizingMaskIntoConstraints = false

        let textStack = NSStackView()
        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = 3
        textStack.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .systemFont(ofSize: 13, weight: .medium)
        titleLabel.lineBreakMode = .byTruncatingTail

        let detailLabel = NSTextField(wrappingLabelWithString: detail)
        detailLabel.font = .systemFont(ofSize: 11, weight: .regular)
        detailLabel.textColor = .secondaryLabelColor
        detailLabel.maximumNumberOfLines = 2

        textStack.addArrangedSubview(titleLabel)
        textStack.addArrangedSubview(detailLabel)

        control.translatesAutoresizingMaskIntoConstraints = false
        control.setContentHuggingPriority(.required, for: .horizontal)
        control.setContentCompressionResistancePriority(.required, for: .horizontal)

        row.addSubview(textStack)
        row.addSubview(control)

        NSLayoutConstraint.activate([
            row.heightAnchor.constraint(greaterThanOrEqualToConstant: 66),

            textStack.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 16),
            textStack.trailingAnchor.constraint(lessThanOrEqualTo: control.leadingAnchor, constant: -20),
            textStack.centerYAnchor.constraint(equalTo: row.centerYAnchor),

            control.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -16),
            control.centerYAnchor.constraint(equalTo: row.centerYAnchor)
        ])

        return row
    }

    private func separator() -> NSBox {
        let separator = NSBox()
        separator.boxType = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false
        separator.heightAnchor.constraint(equalToConstant: 1).isActive = true
        return separator
    }

    private func actionButton(title: String, action: Selector) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        button.bezelStyle = .rounded
        button.controlSize = .regular
        return button
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

    private func configureSwitch(_ control: NSSwitch, action: Selector) {
        control.target = self
        control.action = action
        control.controlSize = .regular
    }

    private func syncControls() {
        selectPopupItem(sleepModePopup, rawValue: AppPreferences.sleepPreventionMode.rawValue)
        selectPopupItem(menuBarDisplayPopup, rawValue: AppPreferences.menuBarDisplayMode.rawValue)
        launchSwitch.state = AppPreferences.enableOnLaunch ? .on : .off
        hotKeySwitch.state = AppPreferences.globalHotKeyEnabled ? .on : .off
        updateChecksSwitch.state = AppPreferences.automaticUpdateChecksEnabled ? .on : .off
        notifyStatusSwitch.state = AppPreferences.notifyStatusChanges ? .on : .off
        notifyTimerSwitch.state = AppPreferences.notifyTimerEvents ? .on : .off
        notifyBatterySwitch.state = AppPreferences.notifyBatteryEvents ? .on : .off
        customDurationField.integerValue = AppPreferences.customDurationMinutes
        customDurationStepper.integerValue = AppPreferences.customDurationMinutes
        selectPopupItem(batteryProtectionPopup, rawValue: AppPreferences.batteryProtectionMode.rawValue)
        restoreAfterPowerSwitch.state = AppPreferences.restoreAfterPowerConnected ? .on : .off
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
        sleepModePopup.controlSize = .regular
        sleepModePopup.widthAnchor.constraint(equalToConstant: 280).isActive = true
    }

    private func configureMenuBarDisplayPopup() {
        menuBarDisplayPopup.removeAllItems()
        for mode in MenuBarDisplayMode.allCases {
            menuBarDisplayPopup.addItem(withTitle: mode.title)
            menuBarDisplayPopup.lastItem?.representedObject = mode.rawValue
        }
        menuBarDisplayPopup.target = self
        menuBarDisplayPopup.action = #selector(changeMenuBarDisplayMode)
        menuBarDisplayPopup.controlSize = .regular
        menuBarDisplayPopup.widthAnchor.constraint(equalToConstant: 280).isActive = true
    }

    private func configureBatteryProtectionPopup() {
        batteryProtectionPopup.removeAllItems()
        for mode in BatteryProtectionMode.allCases {
            batteryProtectionPopup.addItem(withTitle: mode.title)
            batteryProtectionPopup.lastItem?.representedObject = mode.rawValue
        }
        batteryProtectionPopup.target = self
        batteryProtectionPopup.action = #selector(changeBatteryProtectionMode)
        batteryProtectionPopup.controlSize = .regular
        batteryProtectionPopup.widthAnchor.constraint(equalToConstant: 280).isActive = true
    }

    private func selectPopupItem(_ popup: NSPopUpButton, rawValue: Int) {
        for item in popup.itemArray where item.representedObject as? Int == rawValue {
            popup.select(item)
            return
        }
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        panes.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard panes.indices.contains(row) else {
            return nil
        }

        let cell = tableView.makeView(
            withIdentifier: .preferencesPaneCell,
            owner: self
        ) as? SidebarCellView ?? SidebarCellView()
        cell.identifier = .preferencesPaneCell
        cell.configure(with: panes[row])
        return cell
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        let row = sidebarTable.selectedRow
        guard panes.indices.contains(row) else {
            return
        }

        selectedPane = panes[row]
        renderSelectedPane()
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
        AppPreferences.enableOnLaunch = launchSwitch.state == .on
        onPreferencesChanged?()
    }

    @objc private func toggleHotKey() {
        AppPreferences.globalHotKeyEnabled = hotKeySwitch.state == .on
        onPreferencesChanged?()
    }

    @objc private func toggleUpdateChecks() {
        AppPreferences.automaticUpdateChecksEnabled = updateChecksSwitch.state == .on
        onPreferencesChanged?()
    }

    @objc private func toggleStatusNotifications() {
        AppPreferences.notifyStatusChanges = notifyStatusSwitch.state == .on
        onPreferencesChanged?()
    }

    @objc private func toggleTimerNotifications() {
        AppPreferences.notifyTimerEvents = notifyTimerSwitch.state == .on
        onPreferencesChanged?()
    }

    @objc private func toggleBatteryNotifications() {
        AppPreferences.notifyBatteryEvents = notifyBatterySwitch.state == .on
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
        AppPreferences.restoreAfterPowerConnected = restoreAfterPowerSwitch.state == .on
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

    @objc private func openNotificationSettings() {
        let urls = [
            "x-apple.systempreferences:com.apple.Notifications-Settings.extension",
            "x-apple.systempreferences:com.apple.preference.notifications"
        ]

        for value in urls {
            guard let url = URL(string: value) else {
                continue
            }

            if NSWorkspace.shared.open(url) {
                return
            }
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
        restoreAfterPowerSwitch.isEnabled = AppPreferences.batteryProtectionMode == .autoDisable
        thresholdValueLabel.textColor = isEnabled ? .labelColor : .secondaryLabelColor
    }
}

private final class SidebarCellView: NSTableCellView {
    private let symbolView = NSImageView()
    private let titleField = NSTextField(labelWithString: "")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configureView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with pane: PreferencesWindowController.Pane) {
        let configuration = NSImage.SymbolConfiguration(pointSize: 15, weight: .regular)
        symbolView.image = NSImage(systemSymbolName: pane.symbolName, accessibilityDescription: nil)?
            .withSymbolConfiguration(configuration)
        symbolView.image?.isTemplate = true
        titleField.stringValue = pane.title
    }

    private func configureView() {
        symbolView.translatesAutoresizingMaskIntoConstraints = false
        symbolView.contentTintColor = .labelColor
        symbolView.widthAnchor.constraint(equalToConstant: 20).isActive = true
        symbolView.heightAnchor.constraint(equalToConstant: 20).isActive = true

        titleField.translatesAutoresizingMaskIntoConstraints = false
        titleField.font = .systemFont(ofSize: 13, weight: .medium)
        titleField.lineBreakMode = .byTruncatingTail

        addSubview(symbolView)
        addSubview(titleField)
        imageView = symbolView
        textField = titleField

        NSLayoutConstraint.activate([
            symbolView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            symbolView.centerYAnchor.constraint(equalTo: centerYAnchor),

            titleField.leadingAnchor.constraint(equalTo: symbolView.trailingAnchor, constant: 9),
            titleField.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            titleField.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }
}

private final class SettingsGroupView: NSView {
    override var wantsUpdateLayer: Bool {
        true
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func updateLayer() {
        layer?.cornerRadius = 8
        layer?.masksToBounds = true
        layer?.borderWidth = 1
        layer?.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.72).cgColor
        layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.5).cgColor
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsDisplay = true
    }
}

private extension NSUserInterfaceItemIdentifier {
    static let preferencesPaneColumn = NSUserInterfaceItemIdentifier("PreferencesPaneColumn")
    static let preferencesPaneCell = NSUserInterfaceItemIdentifier("PreferencesPaneCell")
}
