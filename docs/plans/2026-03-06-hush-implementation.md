# Hush Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a macOS menu bar app that detects Spotify ads via MediaRemote and reduces system volume to a configurable floor, restoring it when music resumes.

**Architecture:** Swift Package Manager project with a library target (`HushCore`) containing all logic and an executable target (`Hush`) with the SwiftUI entry point. MediaRemote private framework loaded dynamically. CoreAudio for volume control. State machine drives transitions between idle/normal/dimmed.

**Tech Stack:** Swift 5.9+, SwiftUI, CoreAudio, MediaRemote (private framework), macOS 13+

---

### Task 1: Project Scaffolding

**Files:**
- Create: `Package.swift`
- Create: `Sources/HushCore/HushCore.swift` (placeholder export)
- Create: `Sources/Hush/HushApp.swift`
- Create: `Tests/HushTests/HushTests.swift`

**Step 1: Create SPM package structure**

```bash
cd /Users/ethanflory/Documents/Projects/ad-volume-reducer
mkdir -p Sources/HushCore Sources/Hush Tests/HushTests
```

**Step 2: Write Package.swift**

Create `Package.swift`:
```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Hush",
    platforms: [.macOS(.v13)],
    targets: [
        .target(
            name: "HushCore",
            path: "Sources/HushCore",
            linkerSettings: [
                .linkedFramework("CoreAudio"),
                .linkedFramework("AudioToolbox")
            ]
        ),
        .executableTarget(
            name: "Hush",
            dependencies: ["HushCore"],
            path: "Sources/Hush"
        ),
        .testTarget(
            name: "HushTests",
            dependencies: ["HushCore"],
            path: "Tests/HushTests"
        )
    ]
)
```

**Step 3: Write minimal HushApp entry point**

Create `Sources/Hush/HushApp.swift`:
```swift
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
```

**Step 4: Write placeholder library file**

Create `Sources/HushCore/HushCore.swift`:
```swift
import Foundation

// HushCore library - ad detection and volume control
```

**Step 5: Write placeholder test**

Create `Tests/HushTests/HushTests.swift`:
```swift
import XCTest
@testable import HushCore

final class HushTests: XCTestCase {
    func testPlaceholder() {
        XCTAssertTrue(true)
    }
}
```

**Step 6: Build and run tests to verify setup**

Run: `cd /Users/ethanflory/Documents/Projects/ad-volume-reducer && swift build 2>&1`
Expected: Build succeeds

Run: `swift test 2>&1`
Expected: 1 test passes

**Step 7: Manually verify menu bar icon**

Run: `swift run Hush`
Expected: Speaker icon appears in macOS menu bar. Click shows popover with "Hush" title and Quit button. No dock icon.

Note: Press Ctrl+C to stop, or click Quit in the popover.

**Step 8: Commit**

```bash
git add Package.swift Sources/ Tests/
git commit -m "feat: scaffold Hush project with SPM and menu bar entry point"
```

---

### Task 2: AdClassifier Protocol + SpotifyAdClassifier

**Files:**
- Create: `Sources/HushCore/NowPlayingMetadata.swift`
- Create: `Sources/HushCore/AdClassifier.swift`
- Create: `Sources/HushCore/SpotifyAdClassifier.swift`
- Create: `Tests/HushTests/SpotifyAdClassifierTests.swift`

**Step 1: Write the failing tests**

Create `Tests/HushTests/SpotifyAdClassifierTests.swift`:
```swift
import XCTest
@testable import HushCore

final class SpotifyAdClassifierTests: XCTestCase {
    let classifier = SpotifyAdClassifier()
    let spotifyBundle = "com.spotify.client"

    func testDetectsAdvertisementTitle() {
        let metadata = NowPlayingMetadata(
            title: "Advertisement",
            artist: "",
            album: "",
            bundleID: spotifyBundle,
            playbackRate: 1.0
        )
        XCTAssertTrue(classifier.isAd(metadata: metadata))
    }

    func testDetectsSpotifyArtistAsAd() {
        let metadata = NowPlayingMetadata(
            title: "Spotify",
            artist: "Spotify",
            album: "",
            bundleID: spotifyBundle,
            playbackRate: 1.0
        )
        XCTAssertTrue(classifier.isAd(metadata: metadata))
    }

    func testNormalTrackIsNotAd() {
        let metadata = NowPlayingMetadata(
            title: "Bohemian Rhapsody",
            artist: "Queen",
            album: "A Night at the Opera",
            bundleID: spotifyBundle,
            playbackRate: 1.0
        )
        XCTAssertFalse(classifier.isAd(metadata: metadata))
    }

    func testNonSpotifySourceIsNotAd() {
        let metadata = NowPlayingMetadata(
            title: "Advertisement",
            artist: "",
            album: "",
            bundleID: "com.apple.Music",
            playbackRate: 1.0
        )
        XCTAssertFalse(classifier.isAd(metadata: metadata))
    }

    func testEmptyTitleWithSpotifyArtistIsAd() {
        let metadata = NowPlayingMetadata(
            title: "",
            artist: "Spotify",
            album: "",
            bundleID: spotifyBundle,
            playbackRate: 1.0
        )
        XCTAssertTrue(classifier.isAd(metadata: metadata))
    }

    func testPausedAdIsStillAd() {
        let metadata = NowPlayingMetadata(
            title: "Advertisement",
            artist: "",
            album: "",
            bundleID: spotifyBundle,
            playbackRate: 0.0
        )
        XCTAssertTrue(classifier.isAd(metadata: metadata))
    }
}
```

**Step 2: Run tests to verify they fail**

Run: `swift test --filter SpotifyAdClassifierTests 2>&1`
Expected: Compilation error — `NowPlayingMetadata` and `SpotifyAdClassifier` not found

**Step 3: Write NowPlayingMetadata**

Create `Sources/HushCore/NowPlayingMetadata.swift`:
```swift
import Foundation

public struct NowPlayingMetadata {
    public let title: String
    public let artist: String
    public let album: String
    public let bundleID: String
    public let playbackRate: Double

    public init(title: String, artist: String, album: String, bundleID: String, playbackRate: Double) {
        self.title = title
        self.artist = artist
        self.album = album
        self.bundleID = bundleID
        self.playbackRate = playbackRate
    }
}
```

**Step 4: Write AdClassifier protocol**

Create `Sources/HushCore/AdClassifier.swift`:
```swift
import Foundation

public protocol AdClassifier {
    func isAd(metadata: NowPlayingMetadata) -> Bool
}
```

**Step 5: Write SpotifyAdClassifier**

Create `Sources/HushCore/SpotifyAdClassifier.swift`:
```swift
import Foundation

public struct SpotifyAdClassifier: AdClassifier {
    private static let spotifyBundleID = "com.spotify.client"
    private static let adTitles: Set<String> = ["Advertisement", "Spotify"]
    private static let adArtists: Set<String> = ["", "Spotify"]

    public init() {}

    public func isAd(metadata: NowPlayingMetadata) -> Bool {
        guard metadata.bundleID == Self.spotifyBundleID else { return false }

        return Self.adTitles.contains(metadata.title) ||
               Self.adArtists.contains(metadata.artist)
    }
}
```

**Step 6: Run tests to verify they pass**

Run: `swift test --filter SpotifyAdClassifierTests 2>&1`
Expected: All 6 tests pass

**Step 7: Delete placeholder files**

Remove `Sources/HushCore/HushCore.swift` and `Tests/HushTests/HushTests.swift` (no longer needed).

**Step 8: Commit**

```bash
git add Sources/HushCore/NowPlayingMetadata.swift Sources/HushCore/AdClassifier.swift Sources/HushCore/SpotifyAdClassifier.swift Tests/HushTests/SpotifyAdClassifierTests.swift
git rm Sources/HushCore/HushCore.swift Tests/HushTests/HushTests.swift
git commit -m "feat: add AdClassifier protocol and SpotifyAdClassifier with tests"
```

---

### Task 3: MonitorState State Machine

**Files:**
- Create: `Sources/HushCore/MonitorState.swift`
- Create: `Tests/HushTests/MonitorStateTests.swift`

**Step 1: Write the failing tests**

Create `Tests/HushTests/MonitorStateTests.swift`:
```swift
import XCTest
@testable import HushCore

final class MonitorStateTests: XCTestCase {
    func testIdleToNormalOnMusic() {
        var state = MonitorState.idle
        let result = state.transition(isSpotify: true, isAd: false, isPlaying: true)
        XCTAssertEqual(state, .normal)
        XCTAssertEqual(result, .volumeRestored)
    }

    func testIdleToDimmedOnAd() {
        var state = MonitorState.idle
        let result = state.transition(isSpotify: true, isAd: true, isPlaying: true)
        XCTAssertEqual(state, .dimmed)
        XCTAssertEqual(result, .volumeDimmed)
    }

    func testNormalToDimmedOnAd() {
        var state = MonitorState.normal
        let result = state.transition(isSpotify: true, isAd: true, isPlaying: true)
        XCTAssertEqual(state, .dimmed)
        XCTAssertEqual(result, .volumeDimmed)
    }

    func testDimmedToNormalOnMusic() {
        var state = MonitorState.dimmed
        let result = state.transition(isSpotify: true, isAd: false, isPlaying: true)
        XCTAssertEqual(state, .normal)
        XCTAssertEqual(result, .volumeRestored)
    }

    func testNormalToIdleOnSpotifyStop() {
        var state = MonitorState.normal
        let result = state.transition(isSpotify: false, isAd: false, isPlaying: false)
        XCTAssertEqual(state, .idle)
        XCTAssertEqual(result, .volumeRestored)
    }

    func testDimmedToIdleOnSpotifyStop() {
        var state = MonitorState.dimmed
        let result = state.transition(isSpotify: false, isAd: false, isPlaying: false)
        XCTAssertEqual(state, .idle)
        XCTAssertEqual(result, .volumeRestored)
    }

    func testDimmedStaysDimmedOnPause() {
        var state = MonitorState.dimmed
        let result = state.transition(isSpotify: true, isAd: true, isPlaying: false)
        XCTAssertEqual(state, .dimmed)
        XCTAssertEqual(result, .noChange)
    }

    func testNormalStaysNormalOnSameTrack() {
        var state = MonitorState.normal
        let result = state.transition(isSpotify: true, isAd: false, isPlaying: true)
        XCTAssertEqual(state, .normal)
        XCTAssertEqual(result, .noChange)
    }

    func testIdleStaysIdleOnNonSpotify() {
        var state = MonitorState.idle
        let result = state.transition(isSpotify: false, isAd: false, isPlaying: true)
        XCTAssertEqual(state, .idle)
        XCTAssertEqual(result, .noChange)
    }
}
```

**Step 2: Run tests to verify they fail**

Run: `swift test --filter MonitorStateTests 2>&1`
Expected: Compilation error — `MonitorState` not found

**Step 3: Implement MonitorState**

Create `Sources/HushCore/MonitorState.swift`:
```swift
import Foundation

public enum MonitorAction: Equatable {
    case volumeDimmed
    case volumeRestored
    case noChange
}

public enum MonitorState: Equatable {
    case idle
    case normal
    case dimmed

    /// Transition based on current metadata. Returns the action to take.
    /// Mutates self to the new state.
    @discardableResult
    public mutating func transition(isSpotify: Bool, isAd: Bool, isPlaying: Bool) -> MonitorAction {
        switch self {
        case .idle:
            if isSpotify && isAd {
                self = .dimmed
                return .volumeDimmed
            } else if isSpotify && isPlaying {
                self = .normal
                return .volumeRestored
            }
            return .noChange

        case .normal:
            if !isSpotify || !isPlaying {
                self = .idle
                return .volumeRestored
            } else if isAd {
                self = .dimmed
                return .volumeDimmed
            }
            return .noChange

        case .dimmed:
            if !isSpotify {
                self = .idle
                return .volumeRestored
            } else if !isAd && isPlaying {
                self = .normal
                return .volumeRestored
            }
            return .noChange
        }
    }
}
```

**Step 4: Run tests to verify they pass**

Run: `swift test --filter MonitorStateTests 2>&1`
Expected: All 9 tests pass

**Step 5: Commit**

```bash
git add Sources/HushCore/MonitorState.swift Tests/HushTests/MonitorStateTests.swift
git commit -m "feat: add MonitorState state machine with tests"
```

---

### Task 4: VolumeController

**Files:**
- Create: `Sources/HushCore/VolumeController.swift`

**Step 1: Write VolumeController with CoreAudio integration**

Create `Sources/HushCore/VolumeController.swift`:
```swift
import CoreAudio
import Foundation

public protocol VolumeControlling {
    func getVolume() -> Float
    func setVolume(_ volume: Float)
    func fadeToVolume(_ target: Float, duration: TimeInterval, completion: (() -> Void)?)
    func cancelFade()
}

public final class VolumeController: VolumeControlling {
    private var fadeTimer: Timer?
    private(set) var isAdjusting = false
    private var volumeChangeCallback: ((Float) -> Void)?

    public init() {}

    private var defaultOutputDevice: AudioDeviceID {
        var deviceID = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &deviceID
        )
        return deviceID
    }

    public func getVolume() -> Float {
        var volume: Float32 = 0
        var size = UInt32(MemoryLayout<Float32>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectGetPropertyData(defaultOutputDevice, &address, 0, nil, &size, &volume)
        return volume
    }

    public func setVolume(_ volume: Float) {
        isAdjusting = true
        var vol = max(0, min(1, volume))
        let size = UInt32(MemoryLayout<Float32>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectSetPropertyData(defaultOutputDevice, &address, 0, nil, size, &vol)
        isAdjusting = false
    }

    public func fadeToVolume(_ target: Float, duration: TimeInterval = 1.0, completion: (() -> Void)? = nil) {
        cancelFade()
        let current = getVolume()
        let steps = 20
        let increment = (target - current) / Float(steps)
        let interval = duration / Double(steps)
        var step = 0

        fadeTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] timer in
            step += 1
            if step >= steps {
                self?.setVolume(target)
                timer.invalidate()
                self?.fadeTimer = nil
                completion?()
            } else {
                self?.setVolume(current + increment * Float(step))
            }
        }
    }

    public func cancelFade() {
        fadeTimer?.invalidate()
        fadeTimer = nil
    }

    /// Register a callback for when the user changes volume externally.
    public func onExternalVolumeChange(_ callback: @escaping (Float) -> Void) {
        volumeChangeCallback = callback
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectAddPropertyListenerBlock(defaultOutputDevice, &address, .main) { [weak self] _, _ in
            guard let self = self, !self.isAdjusting else { return }
            let newVolume = self.getVolume()
            self.volumeChangeCallback?(newVolume)
        }
    }
}
```

**Step 2: Build to verify it compiles**

Run: `swift build 2>&1`
Expected: Build succeeds

Note: VolumeController interacts with real audio hardware. Unit testing get/set/fade would require mocking CoreAudio, which adds complexity for little value. The `VolumeControlling` protocol allows mocking in other tests (e.g., MediaMonitor). Manual verification in Task 8.

**Step 3: Commit**

```bash
git add Sources/HushCore/VolumeController.swift
git commit -m "feat: add VolumeController with CoreAudio volume get/set/fade"
```

---

### Task 5: MediaRemote Bridge

**Files:**
- Create: `Sources/HushCore/MediaRemoteBridge.swift`

**Step 1: Write MediaRemoteBridge**

Create `Sources/HushCore/MediaRemoteBridge.swift`:
```swift
import Foundation

public final class MediaRemoteBridge {
    public static let shared = MediaRemoteBridge()

    // Notification name
    public static let nowPlayingInfoDidChange = NSNotification.Name(
        "kMRMediaRemoteNowPlayingInfoDidChangeNotification"
    )
    public static let nowPlayingApplicationDidChange = NSNotification.Name(
        "kMRMediaRemoteNowPlayingApplicationDidChangeNotification"
    )

    // Info dictionary keys
    public static let kTitle = "kMRMediaRemoteNowPlayingInfoTitle"
    public static let kArtist = "kMRMediaRemoteNowPlayingInfoArtist"
    public static let kAlbum = "kMRMediaRemoteNowPlayingInfoAlbum"
    public static let kPlaybackRate = "kMRMediaRemoteNowPlayingInfoPlaybackRate"

    // Function types matching MediaRemote C signatures
    private typealias GetNowPlayingInfoFn = @convention(c) (
        DispatchQueue, @escaping ([String: Any]) -> Void
    ) -> Void
    private typealias RegisterNotificationsFn = @convention(c) (DispatchQueue) -> Void
    private typealias GetBundleIDFn = @convention(c) (
        DispatchQueue, @escaping (CFString) -> Void
    ) -> Void

    private var getNowPlayingInfoFn: GetNowPlayingInfoFn?
    private var registerNotificationsFn: RegisterNotificationsFn?
    private var getBundleIDFn: GetBundleIDFn?

    private init() {
        guard let handle = dlopen(
            "/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote", RTLD_LAZY
        ) else {
            print("Hush: Failed to load MediaRemote framework")
            return
        }

        if let sym = dlsym(handle, "MRMediaRemoteGetNowPlayingInfo") {
            getNowPlayingInfoFn = unsafeBitCast(sym, to: GetNowPlayingInfoFn.self)
        }
        if let sym = dlsym(handle, "MRMediaRemoteRegisterForNowPlayingNotifications") {
            registerNotificationsFn = unsafeBitCast(sym, to: RegisterNotificationsFn.self)
        }
        if let sym = dlsym(handle, "MRMediaRemoteGetNowPlayingApplicationBundleIdentifier") {
            getBundleIDFn = unsafeBitCast(sym, to: GetBundleIDFn.self)
        }
    }

    /// Call once at startup to register for Now Playing notifications.
    public func registerForNotifications() {
        registerNotificationsFn?(.main)
    }

    /// Get current Now Playing info. Calls completion with metadata on main queue.
    public func getNowPlayingInfo(completion: @escaping (NowPlayingMetadata?) -> Void) {
        guard let getInfo = getNowPlayingInfoFn, let getBundleID = getBundleIDFn else {
            completion(nil)
            return
        }

        getBundleID(.main) { bundleID in
            getInfo(.main) { info in
                let title = info[MediaRemoteBridge.kTitle] as? String ?? ""
                let artist = info[MediaRemoteBridge.kArtist] as? String ?? ""
                let album = info[MediaRemoteBridge.kAlbum] as? String ?? ""
                let playbackRate = info[MediaRemoteBridge.kPlaybackRate] as? Double ?? 0.0

                let metadata = NowPlayingMetadata(
                    title: title,
                    artist: artist,
                    album: album,
                    bundleID: bundleID as String,
                    playbackRate: playbackRate
                )
                completion(metadata)
            }
        }
    }
}
```

**Step 2: Build to verify it compiles**

Run: `swift build 2>&1`
Expected: Build succeeds

Note: Cannot unit test — requires macOS system with MediaRemote framework available. Will verify manually in Task 8.

**Step 3: Commit**

```bash
git add Sources/HushCore/MediaRemoteBridge.swift
git commit -m "feat: add MediaRemoteBridge for Now Playing metadata access"
```

---

### Task 6: MediaMonitor (Orchestrator)

**Files:**
- Create: `Sources/HushCore/MediaMonitor.swift`

**Step 1: Write MediaMonitor**

Create `Sources/HushCore/MediaMonitor.swift`:
```swift
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
            checkNowPlaying()
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
```

**Step 2: Build to verify it compiles**

Run: `swift build 2>&1`
Expected: Build succeeds

**Step 3: Commit**

```bash
git add Sources/HushCore/MediaMonitor.swift
git commit -m "feat: add MediaMonitor orchestrating ad detection and volume control"
```

---

### Task 7: AppState + Settings Persistence

**Files:**
- Create: `Sources/HushCore/AppState.swift`

**Step 1: Write AppState**

Create `Sources/HushCore/AppState.swift`:
```swift
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
        }
    }

    @Published public var launchAtLogin: Bool {
        didSet {
            UserDefaults.standard.set(launchAtLogin, forKey: "launchAtLogin")
            updateLoginItem()
        }
    }

    public let monitor: MediaMonitor

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

    public init() {
        let defaults = UserDefaults.standard
        // Register defaults
        defaults.register(defaults: [
            "isEnabled": true,
            "volumeFloor": Float(0.05),
            "launchAtLogin": true,
        ])

        self.isEnabled = defaults.bool(forKey: "isEnabled")
        self.volumeFloor = defaults.float(forKey: "volumeFloor")
        self.launchAtLogin = defaults.bool(forKey: "launchAtLogin")
        self.monitor = MediaMonitor()

        if isEnabled {
            monitor.start()
        }
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
```

**Step 2: Build to verify it compiles**

Run: `swift build 2>&1`
Expected: Build succeeds

**Step 3: Commit**

```bash
git add Sources/HushCore/AppState.swift
git commit -m "feat: add AppState with UserDefaults persistence and login item"
```

---

### Task 8: SettingsView (SwiftUI Popover)

**Files:**
- Create: `Sources/Hush/SettingsView.swift`
- Modify: `Sources/Hush/HushApp.swift`

**Step 1: Write SettingsView**

Create `Sources/Hush/SettingsView.swift`:
```swift
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
```

**Step 2: Update HushApp.swift to use AppState and SettingsView**

Replace `Sources/Hush/HushApp.swift` with:
```swift
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
```

**Step 3: Build to verify it compiles**

Run: `swift build 2>&1`
Expected: Build succeeds

**Step 4: Commit**

```bash
git add Sources/Hush/SettingsView.swift Sources/Hush/HushApp.swift
git commit -m "feat: add SettingsView popover and wire up AppState in HushApp"
```

---

### Task 9: Integration Testing + Edge Case Fixes

**Files:**
- Possibly modify: `Sources/HushCore/MediaMonitor.swift`
- Possibly modify: `Sources/HushCore/VolumeController.swift`

**Step 1: Build and run the full app**

Run: `swift build 2>&1 && swift run Hush`
Expected: App builds and launches. Speaker icon appears in menu bar. Click to see popover with all controls.

**Step 2: Test with Spotify**

Manual test checklist:
1. Open Spotify (free tier) and play music
2. Verify popover shows "Listening"
3. Wait for an ad to play
4. Verify: volume drops to floor level, icon changes to `speaker.slash`, status shows "Ad detected — volume dimmed"
5. Wait for ad to end and music to resume
6. Verify: volume fades back up over ~1 second, icon returns to `speaker.wave.2`

**Step 3: Test edge cases**

1. Change system volume during an ad → after ad, volume restores to the new level (not the old one)
2. Toggle the on/off switch during an ad → volume should restore immediately
3. Adjust the volume floor slider → next ad uses new floor
4. Close Spotify while ad is playing → volume restores
5. Launch Hush while an ad is already playing → should detect and dim

**Step 4: Fix any issues found during testing**

Address problems as they arise. Common issues:
- MediaRemote key names may differ on your macOS version — print the info dict to debug
- Bundle ID detection may need adjustment
- Volume listener may fire for our own changes (check `isAdjusting` flag)

Add debug logging if needed:
```swift
// Temporary: add to MediaMonitor.checkNowPlaying() to see raw metadata
print("Hush: metadata = \(String(describing: metadata))")
```

**Step 5: Run all tests**

Run: `swift test 2>&1`
Expected: All tests pass (SpotifyAdClassifierTests + MonitorStateTests)

**Step 6: Commit**

```bash
git add -A
git commit -m "feat: integration testing and edge case fixes"
```

---

### Task 10: README and Final Polish

**Files:**
- Create: `README.md`

**Step 1: Write README**

Create `README.md`:
```markdown
# Hush

A lightweight macOS menu bar app that automatically reduces system volume when Spotify plays ads, then restores it when music resumes.

## Requirements

- macOS 13 (Ventura) or later
- Spotify (free tier)

## Build & Run

```bash
swift build
swift run Hush
```

## How It Works

Hush monitors macOS Now Playing metadata via the MediaRemote framework. When Spotify switches from music to an advertisement, the system volume is immediately reduced to a configurable floor level (default 5%). When music resumes, volume fades back to the previous level over ~1 second.

Volume is reduced, not muted, because Spotify detects muting and pauses playback.

## Settings

Click the speaker icon in the menu bar to access:

- **On/Off toggle** — Enable or disable ad detection
- **Ad volume slider** — Set how quiet ads should be (1%–25%)
- **Launch at login** — Start Hush automatically when you log in

## License

MIT
```

**Step 2: Commit**

```bash
git add README.md
git commit -m "docs: add README"
```
