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
                Text("Hush")
                    .font(.headline)
                Spacer()
                Toggle("", isOn: $appState.isEnabled)
                    .toggleStyle(.switch)
                    .labelsHidden()
            }

            // Status
            Text(appState.statusText)
                .font(.caption)
                .foregroundColor(appState.isDimmed ? .orange : .secondary)

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
