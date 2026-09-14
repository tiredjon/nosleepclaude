import Foundation
import IOKit.pwr_mgt

/// Errors surfaced by `SleepManager`. Every case maps to a concrete IOKit
/// failure or a misuse of the enable/disable lifecycle — never a guess.
enum SleepManagerError: Error, LocalizedError, Equatable {
    case alreadyActive
    case notActive
    case assertionCreationFailed(IOReturn)
    case assertionReleaseFailed(IOReturn)

    var errorDescription: String? {
        switch self {
        case .alreadyActive:
            return "Keep Awake is already active."
        case .notActive:
            return "Keep Awake is not active."
        case .assertionCreationFailed(let code):
            return "Failed to create the sleep-prevention assertion (IOReturn \(code))."
        case .assertionReleaseFailed(let code):
            return "Failed to release the sleep-prevention assertion (IOReturn \(code))."
        }
    }
}

/// Seam around the raw IOKit power-assertion calls, so `SleepManager`'s
/// lifecycle logic (including failure handling) is unit-testable without
/// needing to provoke a real IOKit failure.
protocol IOPMAssertionProviding {
    func createAssertion(name: String) -> (result: IOReturn, id: IOPMAssertionID)
    func releaseAssertion(_ id: IOPMAssertionID) -> IOReturn
    func assertionExists(_ id: IOPMAssertionID) -> Bool
}

struct RealIOPMAssertionProvider: IOPMAssertionProviding {
    func createAssertion(name: String) -> (result: IOReturn, id: IOPMAssertionID) {
        var newID: IOPMAssertionID = IOPMAssertionID(kIOPMNullAssertionID)
        let result = IOPMAssertionCreateWithName(
            kIOPMAssertPreventUserIdleSystemSleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            name as CFString,
            &newID
        )
        return (result, newID)
    }

    func releaseAssertion(_ id: IOPMAssertionID) -> IOReturn {
        IOPMAssertionRelease(id)
    }

    /// Asks powerd directly whether `id` still refers to a live assertion,
    /// via the documented `IOPMAssertionCopyProperties` API. An assertion
    /// that no longer exists yields no properties.
    func assertionExists(_ id: IOPMAssertionID) -> Bool {
        guard let properties = IOPMAssertionCopyProperties(id)?.takeRetainedValue() else {
            return false
        }
        return (properties as NSDictionary).count > 0
    }
}

/// Owns the single IOPM power assertion that prevents idle system sleep.
///
/// Uses `kIOPMAssertPreventUserIdleSystemSleep` — the same assertion type
/// `caffeinate -i` creates. It prevents macOS from sleeping due to user
/// inactivity while the lid is open; it does NOT prevent lid-close sleep.
/// See context/TECHNICAL.md for the primary-source research behind this
/// choice.
final class SleepManager {
    private(set) var isActive: Bool = false
    private var assertionID: IOPMAssertionID = IOPMAssertionID(kIOPMNullAssertionID)

    /// The reason string surfaced by macOS diagnostics (e.g. `pmset -g assertions`).
    private let reason: String
    private let provider: IOPMAssertionProviding

    init(reason: String = "Claude Keep Awake: user-enabled Keep Awake", provider: IOPMAssertionProviding = RealIOPMAssertionProvider()) {
        self.reason = reason
        self.provider = provider
    }

    deinit {
        if isActive {
            _ = provider.releaseAssertion(assertionID)
            Log.sleep.warning("SleepManager deinitialized while still active; released assertion \(self.assertionID, privacy: .public) to avoid a leak.")
        }
    }

    @discardableResult
    func enable() throws -> IOPMAssertionID {
        guard !isActive else {
            Log.sleep.log("enable() called while already active; refusing to create a duplicate assertion.")
            throw SleepManagerError.alreadyActive
        }

        let (result, newID) = provider.createAssertion(name: reason)

        guard result == kIOReturnSuccess else {
            Log.sleep.error("Assertion creation failed with IOReturn \(result, privacy: .public).")
            throw SleepManagerError.assertionCreationFailed(result)
        }

        assertionID = newID
        isActive = true
        Log.sleep.log("Assertion created: id=\(newID, privacy: .public).")
        return newID
    }

    func disable() throws {
        guard isActive else {
            Log.sleep.log("disable() called while not active; nothing to release.")
            throw SleepManagerError.notActive
        }

        let result = provider.releaseAssertion(assertionID)
        guard result == kIOReturnSuccess else {
            Log.sleep.error("Assertion release failed with IOReturn \(result, privacy: .public) for id=\(self.assertionID, privacy: .public).")
            throw SleepManagerError.assertionReleaseFailed(result)
        }

        Log.sleep.log("Assertion released: id=\(self.assertionID, privacy: .public).")
        assertionID = IOPMAssertionID(kIOPMNullAssertionID)
        isActive = false
    }

    /// Re-checks that our assertion is still registered with powerd after a
    /// wake event, and recreates it if it has gone missing. Explicit
    /// assertions normally survive sleep/wake, but this is a defensive
    /// check requested by the project spec rather than an assumption.
    /// Returns `true` if a recreation happened.
    @discardableResult
    func verifyAfterWake() -> Bool {
        guard isActive else { return false }

        guard provider.assertionExists(assertionID) else {
            Log.sleep.warning("Assertion id=\(self.assertionID, privacy: .public) missing after wake; recreating.")
            isActive = false
            assertionID = IOPMAssertionID(kIOPMNullAssertionID)
            do {
                try enable()
                Log.sleep.log("Assertion recreated after wake: id=\(self.assertionID, privacy: .public).")
            } catch {
                Log.sleep.error("Failed to recreate assertion after wake: \(String(describing: error), privacy: .public).")
            }
            return true
        }

        Log.sleep.log("Assertion id=\(self.assertionID, privacy: .public) verified present after wake.")
        return false
    }
}
