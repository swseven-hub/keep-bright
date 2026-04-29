import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let assertion = DisplaySleepAssertion()
    private var statusItem: NSStatusItem?
    private let toggleItem = NSMenuItem()
    private let statusItemLabel = NSMenuItem()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        configureMenuBarItem()
        setKeepBrightEnabled(true)
    }

    func applicationWillTerminate(_ notification: Notification) {
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
        toggleItem.keyEquivalent = ""
        menu.addItem(toggleItem)

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
    }

    @objc private func toggleKeepBright() {
        setKeepBrightEnabled(!assertion.isActive)
    }

    private func setKeepBrightEnabled(_ isEnabled: Bool) {
        if isEnabled {
            _ = assertion.enable()
        } else {
            assertion.disable()
        }

        updateMenuState()

        if isEnabled, !assertion.isActive {
            showAssertionError()
        }
    }

    private func updateMenuState() {
        let isEnabled = assertion.isActive
        statusItemLabel.title = isEnabled ? "保持亮屏：已开启" : "保持亮屏：已关闭"
        toggleItem.title = isEnabled ? "关闭保持亮屏" : "开启保持亮屏"
        toggleItem.state = isEnabled ? .on : .off

        if let button = statusItem?.button {
            button.image = statusImage(isEnabled: isEnabled)
            button.toolTip = isEnabled ? "保持亮屏已开启" : "保持亮屏已关闭"
        }
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
        alert.messageText = "保持亮屏"
        alert.informativeText = "一个原生 macOS 菜单栏工具。开启后会阻止屏幕因闲置而自动变暗或息屏，退出应用时会自动恢复系统默认行为。"
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
}
