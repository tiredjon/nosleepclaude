import SwiftUI
import AppKit

/// The menu bar icon + title. Reflects only actually-known state.
struct MenuBarLabel: View {
    @ObservedObject var appState: AppState

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: appState.isKeepAwakeActive ? "bolt.fill" : "bolt.slash")
            Text(appState.isKeepAwakeActive ? "ACTIVE" : "INACTIVE")
        }
    }
}

/// The dropdown content shown when the menu bar icon is clicked.
struct MenuBarView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Keep Awake")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Text(appState.isKeepAwakeActive ? "ACTIVE" : "INACTIVE")
                    .font(.system(size: 11, weight: .bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(appState.isKeepAwakeActive ? Color.green.opacity(0.2) : Color.gray.opacity(0.2))
                    .foregroundStyle(appState.isKeepAwakeActive ? Color.green : Color.secondary)
                    .clipShape(Capsule())
            }

            Button {
                appState.toggleKeepAwake()
            } label: {
                Text(appState.isKeepAwakeActive ? "Disable Keep Awake" : "Enable Keep Awake")
                    .frame(maxWidth: .infinity)
            }
            .controlSize(.large)

            if appState.showBatteryWarning {
                BatteryWarningBanner {
                    appState.dismissBatteryWarning()
                }
            }

            if let error = appState.lastErrorMessage {
                Text(error)
                    .font(.system(size: 11))
                    .foregroundStyle(.red)
            }

            Divider()

            StatusView(appState: appState)

            Divider()

            SettingsView(appState: appState)

            Divider()

            Text("Prevents idle sleep only. Closed-lid operation still requires your own clamshell-mode setup (AC power + external display) — see README.")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Divider()

            Button("Quit Claude Keep Awake") {
                NSApplication.shared.terminate(nil)
            }
            .font(.system(size: 12))
        }
        .padding(14)
        .frame(width: 280)
    }
}

private struct BatteryWarningBanner: View {
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text("Preventing sleep on battery can significantly increase battery use.")
                .font(.system(size: 11))
            Spacer()
            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(8)
        .background(Color.orange.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}
