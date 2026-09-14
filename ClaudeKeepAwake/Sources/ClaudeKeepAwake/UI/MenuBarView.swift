import SwiftUI
import AppKit

/// The menu bar icon. Icon-only (no text) to match standard macOS menu bar
/// conventions; shape change (not color) signals state, per HIG guidance
/// that menu bar glyphs stay monochrome/template.
struct MenuBarLabel: View {
    @ObservedObject var appState: AppState

    private var symbolName: String {
        appState.isKeepAwakeActive ? "bolt.fill" : "moon.zzz"
    }

    var body: some View {
        Group {
            if #available(macOS 14.0, *) {
                Image(systemName: symbolName)
                    .contentTransition(.symbolEffect(.replace))
            } else {
                Image(systemName: symbolName)
            }
        }
        .font(.system(size: 13, weight: .medium))
        .animation(.smooth(duration: 0.25), value: appState.isKeepAwakeActive)
        .help(appState.isKeepAwakeActive ? "No Sleep Claude — Active" : "No Sleep Claude — Inactive")
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
                StatusBadge(isActive: appState.isKeepAwakeActive)
            }

            Button {
                withAnimation(.smooth(duration: 0.25)) {
                    appState.toggleKeepAwake()
                }
            } label: {
                Text(appState.isKeepAwakeActive ? "Disable Keep Awake" : "Enable Keep Awake")
                    .frame(maxWidth: .infinity)
            }
            .controlSize(.large)
            .buttonStyle(.borderedProminent)
            .tint(appState.isKeepAwakeActive ? .secondary : .accentColor)

            if appState.showBatteryWarning {
                BatteryWarningBanner {
                    withAnimation(.smooth(duration: 0.2)) {
                        appState.dismissBatteryWarning()
                    }
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            if let error = appState.lastErrorMessage {
                Text(error)
                    .font(.system(size: 11))
                    .foregroundStyle(.red)
                    .transition(.opacity)
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

            Button("Quit No Sleep Claude") {
                NSApplication.shared.terminate(nil)
            }
            .font(.system(size: 12))
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(width: 280)
        .animation(.smooth(duration: 0.2), value: appState.showBatteryWarning)
        .animation(.smooth(duration: 0.2), value: appState.lastErrorMessage)
    }
}

private struct StatusBadge: View {
    let isActive: Bool

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(isActive ? Color.green : Color.secondary.opacity(0.5))
                .frame(width: 6, height: 6)
                .modifier(PulseWhenActive(isActive: isActive))
            Text(isActive ? "ACTIVE" : "INACTIVE")
                .font(.system(size: 11, weight: .bold))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(isActive ? Color.green.opacity(0.15) : Color.secondary.opacity(0.12))
        .foregroundStyle(isActive ? Color.green : Color.secondary)
        .clipShape(Capsule())
        .animation(.smooth(duration: 0.25), value: isActive)
    }
}

/// Subtle "breathing" glow on the status dot while active — the one bit of
/// ambient motion in the UI, used sparingly so it reads as alive, not busy.
private struct PulseWhenActive: ViewModifier {
    let isActive: Bool
    @State private var pulse = false

    func body(content: Content) -> some View {
        content
            .opacity(isActive && pulse ? 0.4 : 1.0)
            .onAppear { startIfNeeded() }
            .onChange(of: isActive) { _ in startIfNeeded() }
            .animation(isActive ? .easeInOut(duration: 1.1).repeatForever(autoreverses: true) : .default, value: pulse)
    }

    private func startIfNeeded() {
        pulse = isActive
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
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
