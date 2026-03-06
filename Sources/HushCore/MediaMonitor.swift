import Combine
import Foundation

public final class MediaMonitor: ObservableObject {
    @Published public private(set) var state: MonitorState = .idle
    @Published public private(set) var currentMetadata: NowPlayingMetadata?
    @Published public private(set) var isEnabled: Bool = true

    private let classifier: AdClassifier
    private let volumeController: VolumeController
    private let bridge: MediaRemoteBridge
    private var previousVolume: Float = 0.5

    public init(
        classifier: AdClassifier = SpotifyAdClassifier(),
        volumeController: VolumeController = VolumeController(),
        bridge: MediaRemoteBridge = .shared
    ) {
        self.classifier = classifier
        self.volumeController = volumeController
        self.bridge = bridge
    }

    public func start() {
        bridge.registerForNotifications()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(nowPlayingChanged),
            name: MediaRemoteBridge.nowPlayingInfoDidChange,
            object: nil
        )

        // Also listen for app changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(nowPlayingChanged),
            name: MediaRemoteBridge.nowPlayingApplicationDidChange,
            object: nil
        )

        // Listen for external volume changes while dimmed
        volumeController.onExternalVolumeChange { [weak self] newVolume in
            guard let self = self, self.state == .dimmed else { return }
            // User changed volume during ad — update the restore target
            self.previousVolume = newVolume
        }

        // Check current state on launch (handles launch mid-ad)
        checkNowPlaying()
    }

    public func stop() {
        NotificationCenter.default.removeObserver(self)
        if state == .dimmed {
            restoreVolume()
        }
        state = .idle
    }

    public func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        if enabled {
            start()
        } else {
            stop()
        }
    }

    @objc private func nowPlayingChanged() {
        guard isEnabled else { return }
        checkNowPlaying()
    }

    private func checkNowPlaying() {
        bridge.getNowPlayingInfo { [weak self] metadata in
            guard let self = self else { return }
            self.currentMetadata = metadata

            let isSpotify: Bool
            let isAd: Bool
            let isPlaying: Bool

            if let metadata = metadata {
                isSpotify = metadata.bundleID == "com.spotify.client"
                isAd = self.classifier.isAd(metadata: metadata)
                isPlaying = metadata.playbackRate > 0
            } else {
                isSpotify = false
                isAd = false
                isPlaying = false
            }

            let action = self.state.transition(
                isSpotify: isSpotify, isAd: isAd, isPlaying: isPlaying
            )

            switch action {
            case .volumeDimmed:
                self.dimVolume()
            case .volumeRestored:
                self.restoreVolume()
            case .noChange:
                break
            }
        }
    }

    private func dimVolume() {
        previousVolume = volumeController.getVolume()
        let floor = UserDefaults.standard.float(forKey: "volumeFloor")
        let effectiveFloor = floor > 0 ? floor : 0.05
        volumeController.cancelFade()
        volumeController.setVolume(effectiveFloor)
    }

    private func restoreVolume() {
        volumeController.fadeToVolume(previousVolume, duration: 1.0, completion: nil)
    }
}
