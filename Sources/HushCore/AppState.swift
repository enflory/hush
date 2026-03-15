import Combine
import Foundation
import ServiceManagement

public final class AppState: ObservableObject {
    @Published public var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: "isEnabled")
            monitor.setEnabled(isEnabled)
        }
    }

    @Published public var volumeFloor: Float {
        didSet {
            UserDefaults.standard.set(volumeFloor, forKey: "volumeFloor")
            monitor.updateVolumeFloor(volumeFloor)
        }
    }

    @Published public var launchAtLogin: Bool {
        didSet {
            UserDefaults.standard.set(launchAtLogin, forKey: "launchAtLogin")
            updateLoginItem()
        }
    }

    public let monitor: MediaMonitor
    private var monitorCancellable: AnyCancellable?

    /// Status text for the UI
    public var statusText: String {
        if !isEnabled { return "Disabled" }
        switch monitor.state {
        case .idle: return "Listening"
        case .normal: return "Listening"
        case .dimmed: return "Ad detected — volume dimmed"
        }
    }

    /// Whether the menu bar icon should show the dimmed variant
    public var isDimmed: Bool {
        isEnabled && monitor.state == .dimmed
    }

    /// SF Symbol name for the menu bar icon reflecting current state
    public var menuBarIcon: String {
        isDimmed ? "music.note.slash" : "music.note"
    }

    public init() {
        let defaults = UserDefaults.standard
        // Register defaults
        defaults.register(defaults: [
            "isEnabled": true,
            "volumeFloor": Float(0.01),
            "launchAtLogin": true,
        ])

        self.isEnabled = defaults.bool(forKey: "isEnabled")
        self.volumeFloor = defaults.float(forKey: "volumeFloor")
        self.launchAtLogin = defaults.bool(forKey: "launchAtLogin")
        self.monitor = MediaMonitor()

        // Forward monitor changes so SwiftUI re-evaluates isDimmed/statusText
        monitorCancellable = monitor.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }

        if isEnabled {
            monitor.start()
        }

        updateLoginItem()
    }

    private func updateLoginItem() {
        if #available(macOS 13.0, *) {
            do {
                if launchAtLogin {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                print("Hush: Failed to update login item: \(error)")
            }
        }
    }
}
