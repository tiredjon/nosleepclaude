import Foundation
import Combine

private enum DefaultsKey {
    static let startActive = "startActive"
    static let batteryWarningEnabled = "batteryWarningEnabled"
}

/// Owns the observable state SwiftUI binds to, and coordinates the Core/
/// Services layer. Contains no direct IOKit/AppKit power-management calls
/// itself — those live in `SleepManager`, `PowerMonitor`, `SystemEvents`,
/// `LaunchAtLoginManager`.
final class AppState: ObservableObject {
    @Published private(set) var isKeepAwakeActive: Bool = false
    @Published private(set) var powerSource: PowerSourceState = .unknown
    @Published private(set) var batteryPercentage: Int?
    @Published private(set) var isDisplayAsleep: Bool = false
    @Published private(set) var launchAtLoginStatus: LaunchAtLoginStatus = .notRegistered
    @Published var lastErrorMessage: String?
    @Published var showBatteryWarning: Bool = false

    @Published var startActiveSetting: Bool {
        didSet { defaults.set(startActiveSetting, forKey: DefaultsKey.startActive) }
    }

    @Published var batteryWarningEnabled: Bool {
        didSet { defaults.set(batteryWarningEnabled, forKey: DefaultsKey.batteryWarningEnabled) }
    }

    private let sleepManager: SleepManager
    private let powerMonitor: PowerMonitor
    private let systemEvents: SystemEvents
    private let launchAtLoginManager: LaunchAtLoginManager
    private let defaults: UserDefaults

    init(
        sleepManager: SleepManager = SleepManager(),
        powerMonitor: PowerMonitor = PowerMonitor(),
        systemEvents: SystemEvents = SystemEvents(),
        launchAtLoginManager: LaunchAtLoginManager = LaunchAtLoginManager(),
        defaults: UserDefaults = .standard
    ) {
        self.sleepManager = sleepManager
        self.powerMonitor = powerMonitor
        self.systemEvents = systemEvents
        self.launchAtLoginManager = launchAtLoginManager
        self.defaults = defaults

        self.startActiveSetting = defaults.object(forKey: DefaultsKey.startActive) as? Bool ?? false
        self.batteryWarningEnabled = defaults.object(forKey: DefaultsKey.batteryWarningEnabled) as? Bool ?? true
    }

    func start() {
        Log.app.log("App starting.")

        powerMonitor.start { [weak self] state, percentage in
            guard let self else { return }
            self.powerSource = state
            self.batteryPercentage = percentage
            self.reconsiderBatteryWarning()
        }

        systemEvents.start(
            onWillSleep: { [weak self] in
                Log.app.log("System will sleep; assertion (if active) is expected to persist.")
                _ = self
            },
            onDidWake: { [weak self] in
                self?.handleWake()
            },
            onDisplayStateChange: { [weak self] asleep in
                self?.isDisplayAsleep = asleep
            }
        )

        refreshLaunchAtLoginStatus()

        if startActiveSetting {
            Log.app.log("Start Active is enabled; enabling Keep Awake on launch.")
            enableKeepAwake()
        }
    }

    func stop() {
        if isKeepAwakeActive {
            disableKeepAwake()
        }
        powerMonitor.stop()
        systemEvents.stop()
    }

    // MARK: - Keep Awake

    func toggleKeepAwake() {
        isKeepAwakeActive ? disableKeepAwake() : enableKeepAwake()
    }

    func enableKeepAwake() {
        do {
            try sleepManager.enable()
            isKeepAwakeActive = true
            lastErrorMessage = nil
            reconsiderBatteryWarning()
        } catch {
            lastErrorMessage = error.localizedDescription
            Log.app.error("enableKeepAwake failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func disableKeepAwake() {
        do {
            try sleepManager.disable()
            isKeepAwakeActive = false
            lastErrorMessage = nil
            showBatteryWarning = false
        } catch {
            lastErrorMessage = error.localizedDescription
            Log.app.error("disableKeepAwake failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func dismissBatteryWarning() {
        showBatteryWarning = false
    }

    private func reconsiderBatteryWarning() {
        showBatteryWarning = isKeepAwakeActive && batteryWarningEnabled && powerSource == .battery
    }

    private func handleWake() {
        guard isKeepAwakeActive else { return }
        let recreated = sleepManager.verifyAfterWake()
        if recreated && !sleepManager.isActive {
            // Recreation failed; reflect the real state instead of a stale ACTIVE.
            isKeepAwakeActive = false
            lastErrorMessage = "Keep Awake could not be re-established after wake."
        }
        powerMonitor.refresh()
    }

    // MARK: - Launch at Login

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try launchAtLoginManager.enable()
            } else {
                try launchAtLoginManager.disable()
            }
        } catch {
            lastErrorMessage = error.localizedDescription
            Log.app.error("setLaunchAtLogin(\(enabled, privacy: .public)) failed: \(error.localizedDescription, privacy: .public)")
        }
        refreshLaunchAtLoginStatus()
    }

    private func refreshLaunchAtLoginStatus() {
        launchAtLoginStatus = launchAtLoginManager.status
    }
}
