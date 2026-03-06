import HushCore
import SwiftUI

@main
struct HushApp: App {
    @StateObject private var appState = AppState()

    init() {
        NSApp.setActivationPolicy(.accessory)
    }

    var body: some Scene {
        MenuBarExtra {
            SettingsView(appState: appState)
        } label: {
            Image(systemName: appState.isDimmed ? "speaker.slash" : "speaker.wave.2")
        }
        .menuBarExtraStyle(.window)
    }
}
