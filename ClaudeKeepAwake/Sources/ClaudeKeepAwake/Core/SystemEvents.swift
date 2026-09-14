import AppKit

/// Observes macOS sleep/wake and display sleep/wake lifecycle notifications
/// via `NSWorkspace`, the standard public API for these events.
final class SystemEvents {
    private let center = NSWorkspace.shared.notificationCenter
    private var observers: [NSObjectProtocol] = []

    private(set) var isDisplayAsleep: Bool = false

    func start(
        onWillSleep: @escaping () -> Void,
        onDidWake: @escaping () -> Void,
        onDisplayStateChange: ((Bool) -> Void)? = nil
    ) {
        observers.append(center.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: .main
        ) { _ in
            Log.system.log("System will sleep.")
            onWillSleep()
        })

        observers.append(center.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { _ in
            Log.system.log("System did wake.")
            onDidWake()
        })

        observers.append(center.addObserver(
            forName: NSWorkspace.screensDidSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Log.system.log("Display did sleep.")
            self?.isDisplayAsleep = true
            onDisplayStateChange?(true)
        })

        observers.append(center.addObserver(
            forName: NSWorkspace.screensDidWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Log.system.log("Display did wake.")
            self?.isDisplayAsleep = false
            onDisplayStateChange?(false)
        })

        Log.system.log("Sleep/wake observers registered.")
    }

    func stop() {
        for observer in observers {
            center.removeObserver(observer)
        }
        observers.removeAll()
    }

    deinit {
        stop()
    }
}
