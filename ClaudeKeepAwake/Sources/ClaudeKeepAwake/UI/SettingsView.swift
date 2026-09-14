import SwiftUI

struct SettingsView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Toggle(isOn: launchAtLoginBinding) {
                Text("Launch at Login")
            }
            .toggleStyle(.checkbox)
            if appState.launchAtLoginStatus == .requiresApproval {
                Text("Needs approval in System Settings > General > Login Items.")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }

            Toggle(isOn: $appState.startActiveSetting) {
                Text("Start Active")
            }
            .toggleStyle(.checkbox)

            Toggle(isOn: $appState.batteryWarningEnabled) {
                Text("Warn when on Battery")
            }
            .toggleStyle(.checkbox)
        }
        .font(.system(size: 12))
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { appState.launchAtLoginStatus == .enabled || appState.launchAtLoginStatus == .requiresApproval },
            set: { appState.setLaunchAtLogin($0) }
        )
    }
}
