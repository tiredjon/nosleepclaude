import AppKit

/// Owns the single `AppState` instance for the process lifetime and drives
/// its start()/stop() from the real application lifecycle events, so
/// sleep-prevention starts at launch (not only when the menu is first
/// opened) and resources are released correctly on quit.
final class AppDelegate: NSObject, NSApplicationDelegate {
    let appState = AppState()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        Log.app.log("applicationDidFinishLaunching.")
        appState.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        Log.app.log("applicationWillTerminate; releasing resources.")
        appState.stop()
    }
}
