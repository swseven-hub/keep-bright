import Foundation
import IOKit.pwr_mgt

final class DisplaySleepAssertion {
    private var assertionID = IOPMAssertionID(0)

    private(set) var isActive = false
    private(set) var lastError: String?

    @discardableResult
    func enable() -> Bool {
        guard !isActive else {
            return true
        }

        var newAssertionID = IOPMAssertionID(0)
        let localizationBundlePath = Bundle.main.bundlePath as CFString
        let result = IOPMAssertionCreateWithDescription(
            kIOPMAssertPreventUserIdleDisplaySleep as CFString,
            "Keep Bright" as CFString,
            "Keep Bright is preventing the display from sleeping while enabled." as CFString,
            "保持屏幕常亮" as CFString,
            localizationBundlePath,
            0,
            nil,
            &newAssertionID
        )

        guard result == kIOReturnSuccess else {
            lastError = "IOKit returned \(result)."
            return false
        }

        assertionID = newAssertionID
        isActive = true
        lastError = nil
        return true
    }

    func disable() {
        guard isActive else {
            return
        }

        IOPMAssertionRelease(assertionID)
        assertionID = IOPMAssertionID(0)
        isActive = false
        lastError = nil
    }

    deinit {
        disable()
    }
}
