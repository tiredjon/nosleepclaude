import Foundation
import IOKit.ps

enum PowerSourceState: Equatable {
    case ac
    case battery
    case unknown

    var label: String {
        switch self {
        case .ac: return "AC Power"
        case .battery: return "Battery"
        case .unknown: return "Unknown"
        }
    }
}

/// Reports AC/battery power source state using the public
/// `IOKit/ps/IOPowerSources.h` API. Never guesses: if the power source
/// type can't be read, reports `.unknown` rather than assuming AC or
/// battery.
final class PowerMonitor {
    private(set) var currentState: PowerSourceState = .unknown
    private(set) var batteryPercentage: Int?

    private var runLoopSource: CFRunLoopSource?
    private var onChange: ((PowerSourceState, Int?) -> Void)?

    func start(onChange: @escaping (PowerSourceState, Int?) -> Void) {
        self.onChange = onChange
        refresh()

        let context = Unmanaged.passUnretained(self).toOpaque()
        let source = IOPSNotificationCreateRunLoopSource({ context in
            guard let context else { return }
            let monitor = Unmanaged<PowerMonitor>.fromOpaque(context).takeUnretainedValue()
            monitor.refresh()
        }, context)?.takeRetainedValue()

        if let source {
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
            runLoopSource = source
            Log.power.log("Power source change notifications registered.")
        } else {
            Log.power.error("Failed to register power source change notifications; state will only refresh on manual poll.")
        }
    }

    func stop() {
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .defaultMode)
        }
        runLoopSource = nil
        onChange = nil
    }

    @discardableResult
    func refresh() -> PowerSourceState {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef],
              let firstSource = sources.first,
              let description = IOPSGetPowerSourceDescription(snapshot, firstSource)?.takeUnretainedValue() as? [String: Any]
        else {
            Log.power.error("Could not read power source info; reporting Unknown rather than guessing.")
            currentState = .unknown
            batteryPercentage = nil
            onChange?(currentState, batteryPercentage)
            return currentState
        }

        let stateString = description[kIOPSPowerSourceStateKey] as? String
        let newState: PowerSourceState
        switch stateString {
        case kIOPSACPowerValue:
            newState = .ac
        case kIOPSBatteryPowerValue:
            newState = .battery
        default:
            newState = .unknown
        }

        let percentage = description[kIOPSCurrentCapacityKey] as? Int

        if newState != currentState || percentage != batteryPercentage {
            Log.power.log("Power source changed: \(newState.label, privacy: .public), \(percentage.map(String.init) ?? "n/a", privacy: .public)%.")
        }

        currentState = newState
        batteryPercentage = percentage
        onChange?(currentState, batteryPercentage)
        return currentState
    }
}
