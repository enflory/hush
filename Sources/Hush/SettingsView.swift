import HushCore
import SwiftUI

struct SettingsView: View {
    @ObservedObject var appState: AppState

    private var floorPercentage: Int {
        Int(appState.volumeFloor * 100)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Hush")
                        .font(.headline)
                    Text("Auto-dims Spotify ads")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Toggle("", isOn: $appState.isEnabled)
                    .toggleStyle(.switch)
                    .labelsHidden()
            }

            // Status
            Text(appState.statusText)
                .font(.caption)
                .foregroundColor(appState.isDimmed ? .white : .secondary)
                .padding(.horizontal, appState.isDimmed ? 8 : 0)
                .padding(.vertical, appState.isDimmed ? 3 : 0)
                .background(appState.isDimmed ? Color.red.opacity(0.75) : Color.clear)
                .clipShape(Capsule())

            Divider()

            // Volume floor slider
            VStack(alignment: .leading, spacing: 4) {
                Text("Ad volume: \(floorPercentage)%")
                    .font(.caption)
                Slider(
                    value: $appState.volumeFloor,
                    in: 0.01...0.25,
                    step: 0.01
                )
            }

            // Launch at login
            Toggle("Launch at login", isOn: $appState.launchAtLogin)
                .font(.caption)

            Divider()

            // Quit
            Button("Quit Hush") {
                NSApplication.shared.terminate(nil)
            }
            .font(.caption)
        }
        .padding()
        .frame(width: 240)
    }
}
