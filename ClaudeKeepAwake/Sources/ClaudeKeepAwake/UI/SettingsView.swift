import SwiftUI

struct SettingsView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: launchAtLoginBinding) {
                Text("Launch at Login")
            }
            .toggleStyle(.switch)
            .controlSize(.small)
            if appState.launchAtLoginStatus == .requiresApproval {
                Text("Needs approval in System Settings > General > Login Items.")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .transition(.opacity)
            }

            Toggle(isOn: $appState.startActiveSetting) {
                Text("Start Active")
            }
            .toggleStyle(.switch)
            .controlSize(.small)

            Toggle(isOn: $appState.batteryWarningEnabled) {
                Text("Warn when on Battery")
            }
            .toggleStyle(.switch)
            .controlSize(.small)
        }
        .font(.system(size: 12))
        .animation(.smooth(duration: 0.2), value: appState.launchAtLoginStatus)
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { appState.launchAtLoginStatus == .enabled || appState.launchAtLoginStatus == .requiresApproval },
            set: { appState.setLaunchAtLogin($0) }
        )
    }
}
