import SwiftUI

struct StatusRow: View {
    let label: String
    let value: String
    var valueColor: Color = .primary

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .foregroundStyle(valueColor)
                .fontWeight(.medium)
        }
        .font(.system(size: 12))
    }
}

/// Status readout. Only ever shows values the app actually knows; there is
/// deliberately no "Lid" row — see context/DECISIONS.md (no public API to
/// read lid state, and the project forbids displaying guessed values).
struct StatusView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            StatusRow(
                label: "System Sleep",
                value: appState.isKeepAwakeActive ? "PREVENTED (idle)" : "Not prevented",
                valueColor: appState.isKeepAwakeActive ? .green : .secondary
            )
            StatusRow(
                label: "Display Sleep",
                value: appState.isDisplayAsleep ? "Asleep" : "Awake"
            )
            StatusRow(
                label: "Power",
                value: powerLabel,
                valueColor: appState.powerSource == .battery ? .orange : .primary
            )
        }
        .animation(.smooth(duration: 0.2), value: appState.isKeepAwakeActive)
        .animation(.smooth(duration: 0.2), value: appState.isDisplayAsleep)
        .animation(.smooth(duration: 0.2), value: appState.powerSource)
        .animation(.smooth(duration: 0.2), value: appState.batteryPercentage)
    }

    private var powerLabel: String {
        switch appState.powerSource {
        case .ac:
            return "AC Power"
        case .battery:
            if let pct = appState.batteryPercentage {
                return "Battery (\(pct)%)"
            }
            return "Battery"
        case .unknown:
            return "Unknown"
        }
    }
}
