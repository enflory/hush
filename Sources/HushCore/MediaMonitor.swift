import Combine
import Foundation

public final class MediaMonitor: ObservableObject {
    @Published public private(set) var state: MonitorState = .idle
    @Published public private(set) var currentMetadata: NowPlayingMetadata?
    @Published public private(set) var isEnabled: Bool = true

    private let classifier: AdClassifier
    private let volumeController: VolumeControlling
    private let bridge: MediaRemoteBridge
    private var restoreTarget: Float = 0.5
    private var pollTimer: Timer?
    private static let pollInterval: TimeInterval = 2.0

    public init(
        classifier: AdClassifier = SpotifyAdClassifier(),
        volumeController: VolumeControlling = VolumeController(),
        bridge: MediaRemoteBridge = .shared
    ) {
        self.classifier = classifier
        self.volumeController = volumeController
        self.bridge = bridge
    }

    public func start() {
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: Self.pollInterval, repeats: true) { [weak self] _ in
            guard let self = self, self.isEnabled else { return }
            self.checkNowPlaying()
        }

        checkNowPlaying()
    }

    public func stop() {
        pollTimer?.invalidate()
        pollTimer = nil
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

    public func updateVolumeFloor(_ floor: Float) {
        guard state == .dimmed else { return }
        let effectiveFloor = floor > 0 ? floor : 0.0625
        volumeController.setVolume(effectiveFloor)
    }

    #if DEBUG
    /// For testing only — set state directly.
    public func simulateStateForTesting(_ newState: MonitorState) {
        state = newState
    }
    #endif

    private func dimVolume() {
        restoreTarget = volumeController.getVolume()
        let floor = UserDefaults.standard.float(forKey: "volumeFloor")
        let effectiveFloor = floor > 0 ? floor : 0.0625
        volumeController.cancelFade()
        volumeController.setVolume(effectiveFloor)
    }

    private func restoreVolume() {
        volumeController.fadeToVolume(restoreTarget, duration: 1.0, completion: nil)
    }
}
