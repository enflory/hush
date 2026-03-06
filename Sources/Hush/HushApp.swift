import HushCore
import SwiftUI

@main
struct HushApp: App {
    @NSApplicationDelegateAdaptor(HushAppDelegate.self) var appDelegate
    @StateObject private var appState = AppState()

    var body: some Scene {
        MenuBarExtra {
            SettingsView(appState: appState)
        } label: {
            Image(systemName: appState.isDimmed ? "speaker.slash" : "speaker.wave.2")
        }
        .menuBarExtraStyle(.window)
    }
}

class HushAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}
