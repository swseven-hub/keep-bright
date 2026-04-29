import Foundation
import IOKit.ps

struct BatteryState {
    let isOnBatteryPower: Bool
    let chargePercent: Int?

    var isConnectedToPower: Bool {
        !isOnBatteryPower
    }

    func isBelowOrEqual(to threshold: Int) -> Bool {
        guard isOnBatteryPower, let chargePercent else {
            return false
        }

        return chargePercent <= threshold
    }
}

final class BatteryMonitor {
    var onStateEvaluated: ((BatteryState) -> Void)?

    private var timer: Timer?

    func start() {
        stop()

        let timer = Timer(timeInterval: 60, repeats: true) { [weak self] _ in
            self?.evaluate()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func evaluate() {
        let state = currentState()
        onStateEvaluated?(state)
    }

    func shouldPreventEnabling(for mode: BatteryProtectionMode = AppPreferences.batteryProtectionMode) -> BatteryState? {
        guard mode == .autoDisable else {
            return nil
        }

        let state = currentState()
        return state.isBelowOrEqual(to: AppPreferences.batteryProtectionThreshold) ? state : nil
    }

    func currentState() -> BatteryState {
        let info = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let powerSourceType = IOPSGetProvidingPowerSourceType(info).takeUnretainedValue() as String
        let isOnBatteryPower = powerSourceType == kIOPSBatteryPowerValue

        let sources = IOPSCopyPowerSourcesList(info).takeRetainedValue() as [CFTypeRef]

        for source in sources {
            guard let description = IOPSGetPowerSourceDescription(info, source)
                .takeUnretainedValue() as? [String: Any],
                let currentCapacity = description[kIOPSCurrentCapacityKey] as? Int,
                let maxCapacity = description[kIOPSMaxCapacityKey] as? Int,
                maxCapacity > 0 else {
                continue
            }

            let percent = Int(round((Double(currentCapacity) / Double(maxCapacity)) * 100))
            return BatteryState(isOnBatteryPower: isOnBatteryPower, chargePercent: percent)
        }

        return BatteryState(isOnBatteryPower: isOnBatteryPower, chargePercent: nil)
    }

    deinit {
        stop()
    }
}
