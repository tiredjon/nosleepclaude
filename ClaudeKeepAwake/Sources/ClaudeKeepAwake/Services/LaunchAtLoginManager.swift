import Foundation
import ServiceManagement

enum LaunchAtLoginStatus: Equatable {
    case notRegistered
    case enabled
    case requiresApproval
    case notFound
    case unknown

    var label: String {
        switch self {
        case .notRegistered: return "Off"
        case .enabled: return "On"
        case .requiresApproval: return "Needs approval in System Settings"
        case .notFound: return "Not found"
        case .unknown: return "Unknown"
        }
    }
}

/// Wraps `SMAppService.mainApp`, the current (macOS 13+) supported API for
/// registering the running app as a login item. Replaces the deprecated
/// `SMLoginItemSetEnabled` / `LSSharedFileList` mechanisms.
final class LaunchAtLoginManager {
    var status: LaunchAtLoginStatus {
        switch SMAppService.mainApp.status {
        case .notRegistered: return .notRegistered
        case .enabled: return .enabled
        case .requiresApproval: return .requiresApproval
        case .notFound: return .notFound
        @unknown default: return .unknown
        }
    }

    var isEnabled: Bool {
        status == .enabled || status == .requiresApproval
    }

    func enable() throws {
        do {
            try SMAppService.mainApp.register()
            Log.login.log("Registered as a login item; status=\(self.status.label, privacy: .public).")
        } catch {
            Log.login.error("Failed to register login item: \(String(describing: error), privacy: .public).")
            throw error
        }
    }

    func disable() throws {
        do {
            try SMAppService.mainApp.unregister()
            Log.login.log("Unregistered as a login item.")
        } catch {
            Log.login.error("Failed to unregister login item: \(String(describing: error), privacy: .public).")
            throw error
        }
    }
}
