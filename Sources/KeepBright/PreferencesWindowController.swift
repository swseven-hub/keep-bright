import AppKit

final class PreferencesWindowController: NSWindowController, NSTableViewDataSource, NSTableViewDelegate, NSTextFieldDelegate {
    var onPreferencesChanged: (() -> Void)?

    fileprivate enum Pane: Int, CaseIterable {
        case general
        case automation
        case timer
        case battery
        case updates
        case notifications
        case about

        var title: String {
            switch self {
            case .general:
                return "亮屏"
            case .automation:
                return "自动化"
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

        var symbolName: String {
            switch self {
            case .general:
                return "display"
            case .automation:
                return "sparkles"
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
    private let detailScrollView = NSScrollView()
    private let detailStack = FlippedStackView()
    private let detailDocumentView = FlippedDocumentView()

    private let sleepModePopup = NSPopUpButton()
    private let menuBarDisplayPopup = NSPopUpButton()
    private let launchSwitch = NSSwitch()
    private let hotKeySwitch = NSSwitch()
    private let automationAppRulesSwitch = NSSwitch()
    private let automationFullscreenSwitch = NSSwitch()
    private let automationExternalDisplaySwitch = NSSwitch()
    private let automationPowerAdapterSwitch = NSSwitch()
    private let automationAppsField = NSTextField()
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
            contentRect: NSRect(x: 0, y: 0, width: 840, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Keep Bright"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.backgroundColor = .clear
        window.isReleasedWhenClosed = false
        window.setFrame(NSRect(x: 0, y: 0, width: 1120, height: 760), display: false)
        window.minSize = NSSize(width: 940, height: 620)
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
        configureSwitch(automationAppRulesSwitch, action: #selector(toggleAutomationAppRules))
        configureSwitch(automationFullscreenSwitch, action: #selector(toggleAutomationFullscreen))
        configureSwitch(automationExternalDisplaySwitch, action: #selector(toggleAutomationExternalDisplay))
        configureSwitch(automationPowerAdapterSwitch, action: #selector(toggleAutomationPowerAdapter))
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

        automationAppsField.controlSize = .regular
        automationAppsField.bezelStyle = .roundedBezel
        automationAppsField.placeholderString = "Keynote, zoom.us, com.apple.iWork.Keynote, 腾讯会议"
        automationAppsField.target = self
        automationAppsField.action = #selector(changeAutomationAppRules)
        automationAppsField.delegate = self
        automationAppsField.heightAnchor.constraint(equalToConstant: 36).isActive = true
        automationAppsField.setContentHuggingPriority(.defaultLow, for: .horizontal)
        automationAppsField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

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
        thresholdSlider.widthAnchor.constraint(equalToConstant: 220).isActive = true

        thresholdValueLabel.font = .monospacedDigitSystemFont(ofSize: 13, weight: .medium)
        thresholdValueLabel.alignment = .right
        thresholdValueLabel.widthAnchor.constraint(equalToConstant: 44).isActive = true
    }

    private func configureContent() {
        guard let contentView = window?.contentView else {
            return
        }

        let rootGlass = NSGlassEffectView()
        rootGlass.style = .regular
        rootGlass.cornerRadius = 0
        rootGlass.tintColor = NSColor.windowBackgroundColor.withAlphaComponent(0.34)
        rootGlass.translatesAutoresizingMaskIntoConstraints = false

        let rootView = NSView()
        rootView.translatesAutoresizingMaskIntoConstraints = false
        rootView.wantsLayer = true
        rootView.layer?.backgroundColor = NSColor.clear.cgColor

        let rootReadability = ReadabilityBackdropView(alpha: 0.18)
        rootReadability.translatesAutoresizingMaskIntoConstraints = false

        let sidebarView = makeSidebarView()
        let detailView = makeDetailView()

        rootView.addSubview(rootReadability)
        rootView.addSubview(sidebarView)
        rootView.addSubview(detailView)
        rootGlass.contentView = rootView
        contentView.addSubview(rootGlass)

        NSLayoutConstraint.activate([
            rootGlass.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            rootGlass.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            rootGlass.topAnchor.constraint(equalTo: contentView.topAnchor),
            rootGlass.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            rootView.leadingAnchor.constraint(equalTo: rootGlass.leadingAnchor),
            rootView.trailingAnchor.constraint(equalTo: rootGlass.trailingAnchor),
            rootView.topAnchor.constraint(equalTo: rootGlass.topAnchor),
            rootView.bottomAnchor.constraint(equalTo: rootGlass.bottomAnchor),

            rootReadability.leadingAnchor.constraint(equalTo: rootView.leadingAnchor),
            rootReadability.trailingAnchor.constraint(equalTo: rootView.trailingAnchor),
            rootReadability.topAnchor.constraint(equalTo: rootView.topAnchor),
            rootReadability.bottomAnchor.constraint(equalTo: rootView.bottomAnchor),

            sidebarView.leadingAnchor.constraint(equalTo: rootView.leadingAnchor, constant: 14),
            sidebarView.topAnchor.constraint(equalTo: rootView.topAnchor, constant: 14),
            sidebarView.bottomAnchor.constraint(equalTo: rootView.bottomAnchor, constant: -14),
            sidebarView.widthAnchor.constraint(equalToConstant: 260),

            detailView.leadingAnchor.constraint(equalTo: sidebarView.trailingAnchor, constant: 24),
            detailView.trailingAnchor.constraint(equalTo: rootView.trailingAnchor, constant: -28),
            detailView.topAnchor.constraint(equalTo: rootView.topAnchor),
            detailView.bottomAnchor.constraint(equalTo: rootView.bottomAnchor)
        ])
    }

    private func makeSidebarView() -> NSView {
        let wrapper = NSView()
        wrapper.translatesAutoresizingMaskIntoConstraints = false
        wrapper.wantsLayer = true

        let glassView = NSVisualEffectView()
        glassView.material = .sidebar
        glassView.blendingMode = .behindWindow
        glassView.state = .active
        glassView.translatesAutoresizingMaskIntoConstraints = false
        glassView.wantsLayer = true
        glassView.layer?.cornerRadius = 22
        glassView.layer?.masksToBounds = true

        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        glassView.addSubview(container)

        let readabilityBackdrop = ReadabilityBackdropView(alpha: 0.10, cornerRadius: 22)
        readabilityBackdrop.translatesAutoresizingMaskIntoConstraints = false

        let headerView = makeSidebarHeaderView()

        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        let column = NSTableColumn(identifier: .preferencesPaneColumn)
        column.resizingMask = .autoresizingMask
        sidebarTable.addTableColumn(column)
        sidebarTable.headerView = nil
        sidebarTable.rowHeight = 34
        sidebarTable.intercellSpacing = NSSize(width: 0, height: 2)
        sidebarTable.style = .sourceList
        sidebarTable.backgroundColor = .clear
        sidebarTable.usesAlternatingRowBackgroundColors = false
        sidebarTable.focusRingType = .none
        sidebarTable.selectionHighlightStyle = .none
        sidebarTable.delegate = self
        sidebarTable.dataSource = self
        sidebarTable.reloadData()

        scrollView.documentView = sidebarTable
        wrapper.addSubview(glassView)
        container.addSubview(readabilityBackdrop)
        container.addSubview(headerView)
        container.addSubview(scrollView)

        NSLayoutConstraint.activate([
            glassView.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor),
            glassView.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor),
            glassView.topAnchor.constraint(equalTo: wrapper.topAnchor),
            glassView.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor),

            container.leadingAnchor.constraint(equalTo: glassView.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: glassView.trailingAnchor),
            container.topAnchor.constraint(equalTo: glassView.topAnchor),
            container.bottomAnchor.constraint(equalTo: glassView.bottomAnchor),

            readabilityBackdrop.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            readabilityBackdrop.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            readabilityBackdrop.topAnchor.constraint(equalTo: container.topAnchor),
            readabilityBackdrop.bottomAnchor.constraint(equalTo: container.bottomAnchor),

            headerView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 18),
            headerView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -18),
            headerView.topAnchor.constraint(equalTo: container.topAnchor, constant: 40),

            scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 14),
            scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -14),
            scrollView.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: 20),
            scrollView.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -24)
        ])

        wrapper.layer?.shadowColor = NSColor.black.withAlphaComponent(0.05).cgColor
        wrapper.layer?.shadowOpacity = 1
        wrapper.layer?.shadowRadius = 7
        wrapper.layer?.shadowOffset = NSSize(width: 0, height: -0.5)

        return wrapper
    }

    private func makeSidebarHeaderView() -> NSView {
        let header = NSView()
        header.translatesAutoresizingMaskIntoConstraints = false

        let iconView = NSImageView(image: NSImage(named: NSImage.applicationIconName) ?? NSImage())
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.translatesAutoresizingMaskIntoConstraints = false

        let textStack = NSStackView()
        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = 2
        textStack.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = NSTextField(labelWithString: "Keep Bright")
        titleLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        titleLabel.textColor = .labelColor

        let subtitleLabel = NSTextField(labelWithString: "偏好设置")
        subtitleLabel.font = .systemFont(ofSize: 11, weight: .medium)
        subtitleLabel.textColor = .secondaryLabelColor

        textStack.addArrangedSubview(titleLabel)
        textStack.addArrangedSubview(subtitleLabel)

        header.addSubview(iconView)
        header.addSubview(textStack)

        NSLayoutConstraint.activate([
            header.heightAnchor.constraint(equalToConstant: 34),

            iconView.leadingAnchor.constraint(equalTo: header.leadingAnchor),
            iconView.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 28),
            iconView.heightAnchor.constraint(equalToConstant: 28),

            textStack.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 10),
            textStack.trailingAnchor.constraint(lessThanOrEqualTo: header.trailingAnchor),
            textStack.centerYAnchor.constraint(equalTo: header.centerYAnchor)
        ])

        return header
    }

    private func makeDetailView() -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let headerView = makePageHeaderView()

        let scrollView = detailScrollView
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.contentInsets = NSEdgeInsets(top: 0, left: 0, bottom: 10, right: 4)
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        detailDocumentView.translatesAutoresizingMaskIntoConstraints = false
        detailStack.orientation = .vertical
        detailStack.alignment = .leading
        detailStack.distribution = .fill
        detailStack.spacing = 24
        detailStack.translatesAutoresizingMaskIntoConstraints = false
        detailStack.setContentHuggingPriority(.required, for: .vertical)
        detailStack.setContentCompressionResistancePriority(.required, for: .vertical)
        detailDocumentView.addSubview(detailStack)
        scrollView.documentView = detailDocumentView

        container.addSubview(headerView)
        container.addSubview(scrollView)

        let stackWidth = detailStack.widthAnchor.constraint(equalTo: detailDocumentView.widthAnchor, constant: -8)
        stackWidth.priority = .defaultHigh
        let documentContentBottom = detailDocumentView.bottomAnchor.constraint(greaterThanOrEqualTo: detailStack.bottomAnchor, constant: 8)

        NSLayoutConstraint.activate([
            headerView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            headerView.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor),
            headerView.topAnchor.constraint(equalTo: container.topAnchor, constant: 42),

            scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: 24),
            scrollView.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -34),

            detailDocumentView.leadingAnchor.constraint(equalTo: scrollView.contentView.leadingAnchor),
            detailDocumentView.topAnchor.constraint(equalTo: scrollView.contentView.topAnchor),
            detailDocumentView.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor),
            detailDocumentView.heightAnchor.constraint(greaterThanOrEqualTo: scrollView.contentView.heightAnchor),
            detailStack.leadingAnchor.constraint(equalTo: detailDocumentView.leadingAnchor),
            detailStack.trailingAnchor.constraint(lessThanOrEqualTo: detailDocumentView.trailingAnchor, constant: -8),
            detailStack.widthAnchor.constraint(lessThanOrEqualToConstant: 780),
            stackWidth,
            detailStack.topAnchor.constraint(equalTo: detailDocumentView.topAnchor),
            documentContentBottom
        ])

        return container
    }

    private func makePageHeaderView() -> NSView {
        let header = NSView()
        header.translatesAutoresizingMaskIntoConstraints = false

        let titleStack = NSStackView()
        titleStack.orientation = .vertical
        titleStack.alignment = .leading
        titleStack.spacing = 0
        titleStack.translatesAutoresizingMaskIntoConstraints = false

        pageTitleLabel.font = .systemFont(ofSize: 21, weight: .bold)
        pageTitleLabel.textColor = .labelColor
        pageTitleLabel.lineBreakMode = .byTruncatingTail

        titleStack.addArrangedSubview(pageTitleLabel)

        header.addSubview(titleStack)

        NSLayoutConstraint.activate([
            header.heightAnchor.constraint(equalToConstant: 34),
            titleStack.leadingAnchor.constraint(equalTo: header.leadingAnchor),
            titleStack.trailingAnchor.constraint(lessThanOrEqualTo: header.trailingAnchor),
            titleStack.topAnchor.constraint(equalTo: header.topAnchor),
            titleStack.bottomAnchor.constraint(equalTo: header.bottomAnchor)
        ])

        return header
    }

    private func selectPane(_ pane: Pane) {
        selectedPane = pane
        sidebarTable.selectRowIndexes(IndexSet(integer: pane.rawValue), byExtendingSelection: false)
        renderSelectedPane()
    }

    private func renderSelectedPane() {
        pageTitleLabel.stringValue = selectedPane.title

        detailStack.arrangedSubviews.forEach { view in
            detailStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        switch selectedPane {
        case .general:
            renderGeneralPane()
        case .automation:
            renderAutomationPane()
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

        resetDetailScrollPosition()
    }

    private func resetDetailScrollPosition() {
        detailScrollView.contentView.scroll(to: .zero)
        detailScrollView.reflectScrolledClipView(detailScrollView.contentView)

        DispatchQueue.main.async { [weak self] in
            guard let self else {
                return
            }

            self.detailScrollView.contentView.scroll(to: .zero)
            self.detailScrollView.reflectScrolledClipView(self.detailScrollView.contentView)
        }
    }

    private func renderGeneralPane() {
        addDetailView(section(
            title: "行为",
            rows: [
                settingsRow(
                    title: "防睡眠模式",
                    detail: "默认只阻止屏幕息屏；增强模式会额外防止系统因闲置进入睡眠。",
                    symbolName: "moon.zzz",
                    control: sleepModePopup
                ),
                settingsRow(
                    title: "启动后自动开启",
                    detail: "打开 Keep Bright 后立即进入保持亮屏状态。",
                    symbolName: "power",
                    control: launchSwitch
                )
            ]
        ))

        addDetailView(section(
            title: "菜单栏",
            rows: [
                settingsRow(
                    title: "菜单栏显示",
                    detail: "选择杯子图标旁边显示倒计时、防睡眠模式或状态文字。",
                    symbolName: "menubar.rectangle",
                    control: menuBarDisplayPopup
                ),
                settingsRow(
                    title: "全局快捷键",
                    detail: "使用 Option-Command-K 在任意应用中开启或关闭保持亮屏。",
                    symbolName: "keyboard",
                    control: hotKeySwitch
                )
            ]
        ))
    }

    private func renderAutomationPane() {
        addDetailView(section(
            title: "场景规则",
            footer: "自动化只在规则满足时接管；如果你手动关闭，Keep Bright 会暂停自动开启，直到当前规则不再满足。",
            rows: [
                settingsRow(
                    title: "指定 App",
                    detail: "当前台应用匹配下方名称或 Bundle ID 时自动开启。",
                    symbolName: "app.badge",
                    control: automationAppRulesSwitch
                ),
                appListRow(
                    title: "App 列表",
                    detail: "用逗号分隔，例如 Keynote、zoom.us、腾讯会议。",
                    symbolName: "list.bullet"
                ),
                settingsRow(
                    title: "全屏时自动开启",
                    detail: "检测到当前前台 App 有全屏窗口时自动保持亮屏。",
                    symbolName: "arrow.up.left.and.arrow.down.right",
                    control: automationFullscreenSwitch
                ),
                settingsRow(
                    title: "外接显示器",
                    detail: "连接外接显示器或投影时自动保持亮屏。",
                    symbolName: "display",
                    control: automationExternalDisplaySwitch
                ),
                settingsRow(
                    title: "连接电源",
                    detail: "接入电源适配器时自动保持亮屏，拔电后恢复。",
                    symbolName: "powerplug",
                    control: automationPowerAdapterSwitch
                )
            ]
        ))
    }

    private func renderTimerPane() {
        addDetailView(section(
            title: "默认定时",
            footer: "菜单中的“自定义”会使用这里的分钟数。定时运行时可在菜单里快速延长 15 或 30 分钟。",
            rows: [
                settingsRow(
                    title: "自定义时长",
                    detail: "可设置 1 到 720 分钟。",
                    symbolName: "timer",
                    control: customDurationControl()
                )
            ]
        ))
    }

    private func renderBatteryPane() {
        addDetailView(section(
            title: "电池保护",
            footer: "电池保护只在使用电池供电时触发，连接电源时不会自动关闭。",
            rows: [
                settingsRow(
                    title: "低电量保护",
                    detail: "低于阈值后可以只提醒，或自动关闭保持亮屏。",
                    symbolName: "battery.50",
                    control: batteryProtectionPopup
                ),
                settingsRow(
                    title: "电量阈值",
                    detail: "当电池电量低于或等于该数值时触发保护。",
                    symbolName: "slider.horizontal.3",
                    control: thresholdControl()
                ),
                settingsRow(
                    title: "插电后恢复",
                    detail: "如果保持亮屏被电池保护自动关闭，连接电源后自动恢复。",
                    symbolName: "bolt.batteryblock",
                    control: restoreAfterPowerSwitch
                )
            ]
        ))
    }

    private func renderUpdatesPane() {
        addDetailView(section(
            title: "版本检查",
            footer: "自动检查每天最多访问一次 GitHub Releases。手动检查更新可继续在菜单栏中使用。",
            rows: [
                settingsRow(
                    title: "自动检查更新",
                    detail: "发现新版本时显示原生提示，并引导你打开下载页面。",
                    symbolName: "arrow.triangle.2.circlepath",
                    control: updateChecksSwitch
                ),
                settingsRow(
                    title: "发布页面",
                    detail: "查看历史版本、DMG 安装包和校验信息。",
                    symbolName: "shippingbox",
                    control: actionButton(title: "打开 GitHub", symbolName: "arrow.up.forward.app", action: #selector(openGitHub))
                )
            ]
        ))
    }

    private func renderNotificationsPane() {
        addDetailView(section(
            title: "通知类型",
            rows: [
                settingsRow(
                    title: "状态通知",
                    detail: "开启、关闭和插电恢复保持亮屏时提醒。",
                    symbolName: "bell",
                    control: notifyStatusSwitch
                ),
                settingsRow(
                    title: "计时通知",
                    detail: "保持时长更新、延长计时和定时结束时提醒。",
                    symbolName: "timer",
                    control: notifyTimerSwitch
                ),
                settingsRow(
                    title: "电池通知",
                    detail: "低电量提醒和电池保护自动关闭时提醒。",
                    symbolName: "battery.50",
                    control: notifyBatterySwitch
                )
            ]
        ))

        addDetailView(section(
            title: "系统预览",
            footer: "如果通知只显示“1 个通知”或“收到一条通知”，通常是 macOS 的通知预览隐私设置隐藏了正文。",
            rows: [
                settingsRow(
                    title: "通知设置",
                    detail: "在系统设置里将 Keep Bright 的“显示预览”改为“始终”。",
                    symbolName: "gearshape",
                    control: actionButton(title: "打开系统设置", symbolName: "gearshape", action: #selector(openNotificationSettings))
                )
            ]
        ))
    }

    private func renderAboutPane() {
        addDetailView(aboutHeader())
    }

    private func addDetailView(_ view: NSView) {
        detailStack.addArrangedSubview(view)
        view.widthAnchor.constraint(equalTo: detailStack.widthAnchor).isActive = true
    }

    private func aboutHeader() -> NSView {
        let wrapper = NSStackView()
        wrapper.orientation = .vertical
        wrapper.alignment = .centerX
        wrapper.spacing = 20
        wrapper.translatesAutoresizingMaskIntoConstraints = false

        let iconView = NSImageView(image: NSImage(named: NSImage.applicationIconName) ?? NSImage())
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.widthAnchor.constraint(equalToConstant: 150).isActive = true
        iconView.heightAnchor.constraint(equalToConstant: 150).isActive = true

        let title = NSTextField(labelWithString: "Keep Bright")
        title.font = .systemFont(ofSize: 30, weight: .bold)
        title.alignment = .center

        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.7.5"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "17"
        let subtitle = NSTextField(labelWithString: "Version \(version) Build \(build)")
        subtitle.font = .systemFont(ofSize: 17, weight: .semibold)
        subtitle.textColor = .secondaryLabelColor
        subtitle.alignment = .center

        let card = SettingsGroupView()
        card.translatesAutoresizingMaskIntoConstraints = false

        let cardStack = NSStackView()
        cardStack.orientation = .vertical
        cardStack.alignment = .centerX
        cardStack.spacing = 14
        cardStack.translatesAutoresizingMaskIntoConstraints = false

        let description = NSTextField(wrappingLabelWithString: "一个使用 AppKit、IOKit 和系统通知实现的原生 macOS 菜单栏保持亮屏工具。")
        description.font = .systemFont(ofSize: 15, weight: .semibold)
        description.textColor = .secondaryLabelColor
        description.alignment = .center
        description.maximumNumberOfLines = 2

        let links = NSStackView()
        links.orientation = .horizontal
        links.alignment = .centerY
        links.spacing = 12
        links.addArrangedSubview(actionButton(title: "GitHub", symbolName: "chevron.left.forwardslash.chevron.right", action: #selector(openGitHub)))
        links.addArrangedSubview(actionButton(title: "隐私说明", symbolName: "hand.raised", action: #selector(openPrivacy)))

        cardStack.addArrangedSubview(subtitle)
        cardStack.addArrangedSubview(description)
        cardStack.addArrangedSubview(links)
        card.contentContainer.addSubview(cardStack)

        wrapper.addArrangedSubview(iconView)
        wrapper.addArrangedSubview(title)
        wrapper.addArrangedSubview(card)

        NSLayoutConstraint.activate([
            card.widthAnchor.constraint(equalTo: wrapper.widthAnchor),
            cardStack.leadingAnchor.constraint(equalTo: card.contentContainer.leadingAnchor, constant: 24),
            cardStack.trailingAnchor.constraint(equalTo: card.contentContainer.trailingAnchor, constant: -24),
            cardStack.topAnchor.constraint(equalTo: card.contentContainer.topAnchor, constant: 22),
            cardStack.bottomAnchor.constraint(equalTo: card.contentContainer.bottomAnchor, constant: -22)
        ])

        return wrapper
    }

    private func section(title: String, footer: String? = nil, rows: [NSView]) -> NSView {
        let container = NSStackView()
        container.orientation = .vertical
        container.alignment = .leading
        container.spacing = 10
        container.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        titleLabel.textColor = .secondaryLabelColor
        container.addArrangedSubview(titleLabel)

        let group = SettingsGroupView()
        group.translatesAutoresizingMaskIntoConstraints = false
        let rowStack = NSStackView()
        rowStack.orientation = .vertical
        rowStack.alignment = .leading
        rowStack.spacing = 0
        rowStack.translatesAutoresizingMaskIntoConstraints = false
        group.contentContainer.addSubview(rowStack)

        for (index, row) in rows.enumerated() {
            rowStack.addArrangedSubview(row)
            row.widthAnchor.constraint(equalTo: rowStack.widthAnchor).isActive = true
            if index < rows.count - 1 {
                let separator = separator()
                rowStack.addArrangedSubview(separator)
                separator.widthAnchor.constraint(equalTo: rowStack.widthAnchor).isActive = true
            }
        }

        NSLayoutConstraint.activate([
            rowStack.leadingAnchor.constraint(equalTo: group.contentContainer.leadingAnchor),
            rowStack.trailingAnchor.constraint(equalTo: group.contentContainer.trailingAnchor),
            rowStack.topAnchor.constraint(equalTo: group.contentContainer.topAnchor),
            rowStack.bottomAnchor.constraint(equalTo: group.contentContainer.bottomAnchor)
        ])

        container.addArrangedSubview(group)
        group.widthAnchor.constraint(equalTo: container.widthAnchor).isActive = true

        if let footer {
            let footerLabel = NSTextField(wrappingLabelWithString: footer)
            footerLabel.font = .systemFont(ofSize: 13, weight: .regular)
            footerLabel.textColor = .secondaryLabelColor
            footerLabel.maximumNumberOfLines = 3
            container.addArrangedSubview(footerLabel)
            footerLabel.widthAnchor.constraint(equalTo: container.widthAnchor).isActive = true
        }

        return container
    }

    private func settingsRow(title: String, detail: String, symbolName: String, control: NSView) -> NSView {
        let row = NSView()
        row.translatesAutoresizingMaskIntoConstraints = false

        let iconView = SymbolBadgeView(size: 32, pointSize: 15, backgroundAlpha: 0.16, cornerRadius: 9)
        iconView.configure(symbolName: symbolName)

        let textStack = NSStackView()
        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = 3
        textStack.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let detailLabel = NSTextField(wrappingLabelWithString: detail)
        detailLabel.font = .systemFont(ofSize: 12, weight: .regular)
        detailLabel.textColor = .secondaryLabelColor
        detailLabel.maximumNumberOfLines = 2
        detailLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        textStack.addArrangedSubview(titleLabel)
        textStack.addArrangedSubview(detailLabel)
        textStack.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        control.translatesAutoresizingMaskIntoConstraints = false
        control.setContentHuggingPriority(.required, for: .horizontal)
        control.setContentCompressionResistancePriority(.required, for: .horizontal)

        row.addSubview(iconView)
        row.addSubview(textStack)
        row.addSubview(control)

        NSLayoutConstraint.activate([
            row.heightAnchor.constraint(greaterThanOrEqualToConstant: 74),

            iconView.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 18),
            iconView.centerYAnchor.constraint(equalTo: row.centerYAnchor),

            textStack.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 14),
            textStack.trailingAnchor.constraint(lessThanOrEqualTo: control.leadingAnchor, constant: -18),
            textStack.topAnchor.constraint(greaterThanOrEqualTo: row.topAnchor, constant: 14),
            textStack.bottomAnchor.constraint(lessThanOrEqualTo: row.bottomAnchor, constant: -14),
            textStack.centerYAnchor.constraint(equalTo: row.centerYAnchor),

            control.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -20),
            control.centerYAnchor.constraint(equalTo: row.centerYAnchor)
        ])

        return row
    }

    private func appListRow(title: String, detail: String, symbolName: String) -> NSView {
        let row = NSView()
        row.translatesAutoresizingMaskIntoConstraints = false

        let iconView = SymbolBadgeView(size: 32, pointSize: 15, backgroundAlpha: 0.16, cornerRadius: 9)
        iconView.configure(symbolName: symbolName)

        let textStack = NSStackView()
        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = 3
        textStack.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        titleLabel.lineBreakMode = .byTruncatingTail

        let detailLabel = NSTextField(wrappingLabelWithString: detail)
        detailLabel.font = .systemFont(ofSize: 12, weight: .regular)
        detailLabel.textColor = .secondaryLabelColor
        detailLabel.maximumNumberOfLines = 2

        textStack.addArrangedSubview(titleLabel)
        textStack.addArrangedSubview(detailLabel)

        automationAppsField.translatesAutoresizingMaskIntoConstraints = false

        row.addSubview(iconView)
        row.addSubview(textStack)
        row.addSubview(automationAppsField)

        NSLayoutConstraint.activate([
            row.heightAnchor.constraint(greaterThanOrEqualToConstant: 114),

            iconView.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 18),
            iconView.topAnchor.constraint(equalTo: row.topAnchor, constant: 17),

            textStack.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 14),
            textStack.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -20),
            textStack.topAnchor.constraint(equalTo: row.topAnchor, constant: 16),

            automationAppsField.leadingAnchor.constraint(equalTo: textStack.leadingAnchor),
            automationAppsField.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -20),
            automationAppsField.topAnchor.constraint(equalTo: textStack.bottomAnchor, constant: 12),
            automationAppsField.bottomAnchor.constraint(equalTo: row.bottomAnchor, constant: -16)
        ])

        return row
    }

    private func separator() -> NSView {
        let separator = InsetSeparatorView(leftInset: 66, rightInset: 20)
        separator.translatesAutoresizingMaskIntoConstraints = false
        separator.heightAnchor.constraint(equalToConstant: 1).isActive = true
        return separator
    }

    private func actionButton(title: String, symbolName: String, action: Selector) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        button.bezelStyle = .rounded
        button.controlSize = .regular
        if let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil) {
            image.isTemplate = true
            button.image = image
            button.imagePosition = .imageLeading
        }
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
        automationAppRulesSwitch.state = AppPreferences.automationAppRulesEnabled ? .on : .off
        automationFullscreenSwitch.state = AppPreferences.automationFullscreenEnabled ? .on : .off
        automationExternalDisplaySwitch.state = AppPreferences.automationExternalDisplayEnabled ? .on : .off
        automationPowerAdapterSwitch.state = AppPreferences.automationPowerAdapterEnabled ? .on : .off
        automationAppsField.stringValue = AppPreferences.automationAppRules.joined(separator: ", ")
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
        updateAutomationControls()
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
        sleepModePopup.widthAnchor.constraint(equalToConstant: 240).isActive = true
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
        menuBarDisplayPopup.widthAnchor.constraint(equalToConstant: 240).isActive = true
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
        batteryProtectionPopup.widthAnchor.constraint(equalToConstant: 240).isActive = true
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
        cell.configure(with: panes[row], isSelected: row == selectedPane.rawValue)
        return cell
    }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        SidebarRowView()
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        let row = sidebarTable.selectedRow
        guard panes.indices.contains(row) else {
            return
        }

        selectedPane = panes[row]
        sidebarTable.reloadData()
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

    @objc private func toggleAutomationAppRules() {
        AppPreferences.automationAppRulesEnabled = automationAppRulesSwitch.state == .on
        updateAutomationControls()
        onPreferencesChanged?()
    }

    @objc private func toggleAutomationFullscreen() {
        AppPreferences.automationFullscreenEnabled = automationFullscreenSwitch.state == .on
        onPreferencesChanged?()
    }

    @objc private func toggleAutomationExternalDisplay() {
        AppPreferences.automationExternalDisplayEnabled = automationExternalDisplaySwitch.state == .on
        onPreferencesChanged?()
    }

    @objc private func toggleAutomationPowerAdapter() {
        AppPreferences.automationPowerAdapterEnabled = automationPowerAdapterSwitch.state == .on
        onPreferencesChanged?()
    }

    @objc private func changeAutomationAppRules() {
        AppPreferences.automationAppRules = parsedAutomationRules(from: automationAppsField.stringValue)
        automationAppsField.stringValue = AppPreferences.automationAppRules.joined(separator: ", ")
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

    func controlTextDidEndEditing(_ obj: Notification) {
        guard obj.object as? NSTextField == automationAppsField else {
            return
        }

        changeAutomationAppRules()
    }

    private func parsedAutomationRules(from value: String) -> [String] {
        let separators = CharacterSet(charactersIn: ",，;；\n")
        return value
            .components(separatedBy: separators)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func updateAutomationControls() {
        let isEnabled = AppPreferences.automationAppRulesEnabled
        automationAppsField.isEnabled = isEnabled
        automationAppsField.textColor = isEnabled ? .labelColor : .secondaryLabelColor
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
    private let symbolView = SidebarSymbolView(size: 22, pointSize: 16)
    private let titleField = NSTextField(labelWithString: "")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configureView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with pane: PreferencesWindowController.Pane, isSelected: Bool) {
        symbolView.configure(symbolName: pane.symbolName, isSelected: isSelected)
        titleField.stringValue = pane.title
        titleField.textColor = isSelected ? .controlAccentColor : .labelColor
    }

    private func configureView() {
        titleField.translatesAutoresizingMaskIntoConstraints = false
        titleField.font = .systemFont(ofSize: 13, weight: .medium)
        titleField.textColor = .labelColor
        titleField.lineBreakMode = .byTruncatingTail

        addSubview(symbolView)
        addSubview(titleField)
        textField = titleField

        NSLayoutConstraint.activate([
            symbolView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            symbolView.centerYAnchor.constraint(equalTo: centerYAnchor),

            titleField.leadingAnchor.constraint(equalTo: symbolView.trailingAnchor, constant: 10),
            titleField.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            titleField.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }
}

private final class SidebarRowView: NSTableRowView {
    override func drawBackground(in dirtyRect: NSRect) {
        super.drawBackground(in: dirtyRect)
        guard isSelected else {
            return
        }

        drawSelectedBackground()
    }

    override func drawSelection(in dirtyRect: NSRect) {
        drawSelectedBackground()
    }

    private func drawSelectedBackground() {
        let rect = bounds.insetBy(dx: 2, dy: 3)
        let path = NSBezierPath(roundedRect: rect, xRadius: 8, yRadius: 8)
        let isDark = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let fillColor = isDark
            ? NSColor(calibratedWhite: 0.30, alpha: 0.72)
            : NSColor(calibratedWhite: 0.80, alpha: 0.78)
        fillColor.setFill()
        path.fill()
    }
}

private final class SidebarSymbolView: NSView {
    private let imageView = NSImageView()
    private let size: CGFloat
    private let pointSize: CGFloat

    init(size: CGFloat, pointSize: CGFloat) {
        self.size = size
        self.pointSize = pointSize
        super.init(frame: .zero)
        configureView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(symbolName: String, isSelected: Bool) {
        let configuration = NSImage.SymbolConfiguration(pointSize: pointSize, weight: .regular)
        imageView.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)?
            .withSymbolConfiguration(configuration)
        imageView.image?.isTemplate = true
        imageView.contentTintColor = isSelected ? .controlAccentColor : .labelColor
    }

    private func configureView() {
        translatesAutoresizingMaskIntoConstraints = false

        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentTintColor = .labelColor
        addSubview(imageView)

        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: size),
            heightAnchor.constraint(equalToConstant: size),
            imageView.centerXAnchor.constraint(equalTo: centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }
}

private final class FlippedDocumentView: NSView {
    override var isFlipped: Bool {
        true
    }
}

private final class FlippedStackView: NSStackView {
    override var isFlipped: Bool {
        true
    }
}

private final class SymbolBadgeView: NSView {
    private let imageView = NSImageView()
    private let size: CGFloat
    private let pointSize: CGFloat
    private let backgroundAlpha: CGFloat
    private let badgeCornerRadius: CGFloat

    init(size: CGFloat, pointSize: CGFloat, backgroundAlpha: CGFloat, cornerRadius: CGFloat) {
        self.size = size
        self.pointSize = pointSize
        self.backgroundAlpha = backgroundAlpha
        self.badgeCornerRadius = cornerRadius
        super.init(frame: .zero)
        configureView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(symbolName: String) {
        let configuration = NSImage.SymbolConfiguration(pointSize: pointSize, weight: .semibold)
        imageView.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)?
            .withSymbolConfiguration(configuration)
        imageView.image?.isTemplate = true
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateLayerStyling()
    }

    private func configureView() {
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true

        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentTintColor = .controlAccentColor
        addSubview(imageView)

        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: size),
            heightAnchor.constraint(equalToConstant: size),

            imageView.centerXAnchor.constraint(equalTo: centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])

        updateLayerStyling()
    }

    private func updateLayerStyling() {
        layer?.cornerRadius = badgeCornerRadius
        layer?.masksToBounds = false
        layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(backgroundAlpha).cgColor
        layer?.borderWidth = 0
        layer?.shadowOpacity = 0
    }
}

private final class SettingsGroupView: NSGlassEffectView {
    let contentContainer = NSView()
    private let readabilityBackdrop = ReadabilityBackdropView(alpha: 0.50, cornerRadius: 16)

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        style = .regular
        cornerRadius = 16
        tintColor = NSColor.windowBackgroundColor.withAlphaComponent(0.48)
        wantsLayer = true
        contentContainer.translatesAutoresizingMaskIntoConstraints = false

        let wrapper = NSView()
        wrapper.translatesAutoresizingMaskIntoConstraints = false
        wrapper.wantsLayer = true
        wrapper.layer?.cornerRadius = 16
        wrapper.layer?.masksToBounds = true
        readabilityBackdrop.translatesAutoresizingMaskIntoConstraints = false
        wrapper.addSubview(readabilityBackdrop)
        wrapper.addSubview(contentContainer)
        contentView = wrapper

        NSLayoutConstraint.activate([
            wrapper.leadingAnchor.constraint(equalTo: leadingAnchor),
            wrapper.trailingAnchor.constraint(equalTo: trailingAnchor),
            wrapper.topAnchor.constraint(equalTo: topAnchor),
            wrapper.bottomAnchor.constraint(equalTo: bottomAnchor),

            readabilityBackdrop.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor),
            readabilityBackdrop.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor),
            readabilityBackdrop.topAnchor.constraint(equalTo: wrapper.topAnchor),
            readabilityBackdrop.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor),

            contentContainer.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor),
            contentContainer.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor),
            contentContainer.topAnchor.constraint(equalTo: wrapper.topAnchor),
            contentContainer.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor)
        ])

        updateLayerStyling()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateLayerStyling()
    }

    private func updateLayerStyling() {
        layer?.masksToBounds = false
        layer?.borderWidth = 0
        layer?.shadowColor = NSColor.black.withAlphaComponent(0.05).cgColor
        layer?.shadowOpacity = 1
        layer?.shadowRadius = 5
        layer?.shadowOffset = NSSize(width: 0, height: -1)
    }
}

private final class ReadabilityBackdropView: NSView {
    private let alpha: CGFloat
    private let cornerRadius: CGFloat

    init(alpha: CGFloat, cornerRadius: CGFloat = 0) {
        self.alpha = alpha
        self.cornerRadius = cornerRadius
        super.init(frame: .zero)
        wantsLayer = true
        updateLayerColor()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateLayerColor()
    }

    private func updateLayerColor() {
        let isDark = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let baseColor = isDark ? NSColor(calibratedWhite: 0.09, alpha: 1) : NSColor(calibratedWhite: 0.96, alpha: 1)
        let effectiveAlpha = isDark ? min(alpha + 0.04, 0.94) : alpha
        layer?.cornerRadius = cornerRadius
        layer?.masksToBounds = cornerRadius > 0
        layer?.backgroundColor = baseColor.withAlphaComponent(effectiveAlpha).cgColor
    }
}

private final class InsetSeparatorView: NSView {
    private let leftInset: CGFloat
    private let rightInset: CGFloat

    init(leftInset: CGFloat, rightInset: CGFloat) {
        self.leftInset = leftInset
        self.rightInset = rightInset
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let path = NSBezierPath()
        path.lineWidth = 1
        path.move(to: NSPoint(x: leftInset, y: bounds.midY))
        path.line(to: NSPoint(x: bounds.width - rightInset, y: bounds.midY))
        NSColor.separatorColor.withAlphaComponent(0.24).setStroke()
        path.stroke()
    }
}

private extension NSUserInterfaceItemIdentifier {
    static let preferencesPaneColumn = NSUserInterfaceItemIdentifier("PreferencesPaneColumn")
    static let preferencesPaneCell = NSUserInterfaceItemIdentifier("PreferencesPaneCell")
}
