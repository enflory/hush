import SwiftUI
import HushCore

@main
struct HushApp: App {
    init() {
        NSApp.setActivationPolicy(.accessory)
    }

    var body: some Scene {
        MenuBarExtra("Hush", systemImage: "speaker.wave.2") {
            VStack(spacing: 12) {
                Text("Hush")
                    .font(.headline)
                Text("Ad Volume Reducer")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Divider()
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
            }
            .padding()
            .frame(width: 200)
        }
        .menuBarExtraStyle(.window)
    }
}
