import Foundation
import IOKit.pwr_mgt

final class DisplaySleepAssertion {
    private var displayAssertionID = IOPMAssertionID(0)
    private var systemAssertionID = IOPMAssertionID(0)

    private(set) var isActive = false
    private(set) var lastError: String?
    private(set) var mode: SleepPreventionMode = .displayOnly

    @discardableResult
    func enable(mode requestedMode: SleepPreventionMode) -> Bool {
        if isActive, mode == requestedMode {
            return true
        }

        disable()

        let localizationBundlePath = Bundle.main.bundlePath as CFString
        var newDisplayAssertionID = IOPMAssertionID(0)
        let displayResult = IOPMAssertionCreateWithDescription(
            kIOPMAssertPreventUserIdleDisplaySleep as CFString,
            "Keep Bright" as CFString,
            "Keep Bright is preventing the display from sleeping while enabled." as CFString,
            "保持屏幕常亮" as CFString,
            localizationBundlePath,
            0,
            nil,
            &newDisplayAssertionID
        )

        guard displayResult == kIOReturnSuccess else {
            lastError = "Display assertion failed with IOKit code \(displayResult)."
            return false
        }

        displayAssertionID = newDisplayAssertionID

        if requestedMode == .displayAndSystem {
            var newSystemAssertionID = IOPMAssertionID(0)
            let systemResult = IOPMAssertionCreateWithDescription(
                kIOPMAssertPreventUserIdleSystemSleep as CFString,
                "Keep Bright" as CFString,
                "Keep Bright is preventing system idle sleep while enabled." as CFString,
                "防止系统闲置睡眠" as CFString,
                localizationBundlePath,
                0,
                nil,
                &newSystemAssertionID
            )

            guard systemResult == kIOReturnSuccess else {
                IOPMAssertionRelease(displayAssertionID)
                displayAssertionID = IOPMAssertionID(0)
                lastError = "System assertion failed with IOKit code \(systemResult)."
                return false
            }

            systemAssertionID = newSystemAssertionID
        }

        isActive = true
        mode = requestedMode
        lastError = nil
        return true
    }

    func disable() {
        guard isActive else {
            return
        }

        if displayAssertionID != 0 {
            IOPMAssertionRelease(displayAssertionID)
        }
        if systemAssertionID != 0 {
            IOPMAssertionRelease(systemAssertionID)
        }

        displayAssertionID = IOPMAssertionID(0)
        systemAssertionID = IOPMAssertionID(0)
        isActive = false
        lastError = nil
    }

    deinit {
        disable()
    }
}
