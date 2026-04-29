import Foundation
import ServiceManagement

enum LoginItemManager {
    static var status: SMAppService.Status {
        SMAppService.mainApp.status
    }

    static var isEnabled: Bool {
        status == .enabled
    }

    static func setEnabled(_ isEnabled: Bool) throws {
        if isEnabled {
            guard status != .enabled else {
                return
            }

            try SMAppService.mainApp.register()
        } else {
            guard status == .enabled || status == .requiresApproval else {
                return
            }

            try SMAppService.mainApp.unregister()
        }
    }
}
