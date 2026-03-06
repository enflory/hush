# macOS 26 Ad Detection Fix — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace the broken MediaRemote private API with AppleScript-based Spotify polling, fix the state machine, fix the volume restore race condition, and fix the nested ObservableObject UI update issue — all as clean, targeted changes off `main`.

**Architecture:** MediaRemoteBridge gets a complete rewrite from dlopen/dlsym MediaRemote to direct AppleScript queries to Spotify. MediaMonitor switches from notification-driven to 2-second polling. MonitorState fixes spurious volume restores on non-dimmed transitions. VolumeController gets a separate `restoreTarget` to prevent the CoreAudio listener race. AppState forwards nested ObservableObject changes via Combine.

**Tech Stack:** Swift 5.9, SwiftUI, CoreAudio, AppleScript (NSAppleScript), Combine, Swift Testing

**Branch:** `fix/macos26-ad-detection` (off `main`)

---

## Bug Summary

| # | Bug | Root Cause | Severity |
|---|-----|-----------|----------|
| 1 | MediaRemote `getBundleID` symbol removed in macOS 26 | `dlsym` returns nil, `getNowPlayingInfo` early-returns nil | Critical — detection dead |
| 2 | MediaRemote blocked for non-Apple-signed binaries | Private API returns empty data for adhoc-signed binaries | Critical — detection dead |
| 3 | `idle -> normal` triggers `.volumeRestored` | State machine returns wrong action for non-dimmed transitions | Medium — slams volume to 50% on startup |
| 4 | `previousVolume` overwritten by CoreAudio listener | `isAdjusting` reset synchronously, listener fires async on `.main` | High — restore fades to floor instead of original |
| 5 | Menu bar icon/status don't update | Nested `ObservableObject` — SwiftUI only sees `AppState.objectWillChange` | Medium — UI stuck on "Listening" during ads |

---

## Task 1: Add `isAdByURL` to NowPlayingMetadata

**Files:**
- Modify: `Sources/HushCore/NowPlayingMetadata.swift`

**Step 1: Add the `isAdByURL` field**

```swift
// NowPlayingMetadata.swift — full file
import Foundation

public struct NowPlayingMetadata {
    public let title: String
    public let artist: String
    public let album: String
    public let bundleID: String
    public let playbackRate: Double
    public let isAdByURL: Bool

    public init(title: String, artist: String, album: String, bundleID: String, playbackRate: Double, isAdByURL: Bool = false) {
        self.title = title
        self.artist = artist
        self.album = album
        self.bundleID = bundleID
        self.playbackRate = playbackRate
        self.isAdByURL = isAdByURL
    }
}
```

The default value `false` keeps all existing call sites (including tests) compiling without changes.

**Step 2: Build to verify**

Run: `swift build 2>&1 | tail -5`
Expected: Build succeeded

**Step 3: Run tests to verify no regressions**

Run: `swift test 2>&1 | tail -5`
Expected: 15 tests pass

**Step 4: Commit**

```bash
git add Sources/HushCore/NowPlayingMetadata.swift
git commit -m "feat: add isAdByURL field to NowPlayingMetadata"
```

---

## Task 2: Add URL-based ad detection to SpotifyAdClassifier

**Files:**
- Modify: `Sources/HushCore/SpotifyAdClassifier.swift`
- Modify: `Tests/HushTests/SpotifyAdClassifierTests.swift`

**Step 1: Write the failing tests**

Append to `SpotifyAdClassifierTests.swift` (before closing `}`):

```swift
@Test func detectsAdBySpotifyURL() {
    let metadata = NowPlayingMetadata(
        title: "Some Brand Ad",
        artist: "Some Brand",
        album: "",
        bundleID: spotifyBundleID,
        playbackRate: 1.0,
        isAdByURL: true
    )
    #expect(classifier.isAd(metadata: metadata))
}

@Test func normalTrackWithAdURLFlagFalseIsNotAd() {
    let metadata = NowPlayingMetadata(
        title: "Bohemian Rhapsody",
        artist: "Queen",
        album: "A Night at the Opera",
        bundleID: spotifyBundleID,
        playbackRate: 1.0,
        isAdByURL: false
    )
    #expect(!classifier.isAd(metadata: metadata))
}
```

**Step 2: Run tests to verify the first new test fails**

Run: `swift test --filter detectsAdBySpotifyURL 2>&1 | tail -5`
Expected: FAIL — "Some Brand Ad" / "Some Brand" doesn't match existing title/artist heuristics

**Step 3: Add `isAdByURL` check to classifier**

In `SpotifyAdClassifier.swift`, add after the `guard` line (line 11):

```swift
if metadata.isAdByURL { return true }
```

**Step 4: Run all tests**

Run: `swift test 2>&1 | tail -5`
Expected: 17 tests pass (15 original + 2 new)

**Step 5: Commit**

```bash
git add Sources/HushCore/SpotifyAdClassifier.swift Tests/HushTests/SpotifyAdClassifierTests.swift
git commit -m "feat: detect ads by spotify:ad: URL prefix"
```

---

## Task 3: Fix state machine spurious volume restore (Bug #3)

**Files:**
- Modify: `Sources/HushCore/MonitorState.swift`
- Modify: `Tests/HushTests/MonitorStateTests.swift`

**Step 1: Update test expectations first**

In `MonitorStateTests.swift`:

- `idleToNormalOnMusic` (line 10): change `#expect(action == .volumeRestored)` to `#expect(action == .noChange)`
- `normalToIdleOnSpotifyStop` (line 38): change `#expect(action == .volumeRestored)` to `#expect(action == .noChange)`

**Step 2: Run tests to verify they fail**

Run: `swift test --filter MonitorStateTests 2>&1 | tail -10`
Expected: 2 failures — `idleToNormalOnMusic` and `normalToIdleOnSpotifyStop`

**Step 3: Fix the state machine**

In `MonitorState.swift`:

- `idle` case, `else if isSpotify && isPlaying` branch (line 25): change `return .volumeRestored` to `return .noChange`
- `normal` case, `if !isSpotify || !isPlaying` branch (line 34): change `return .volumeRestored` to `return .noChange`

Only `dimmed -> normal` and `dimmed -> idle` should return `.volumeRestored`.

**Step 4: Run all tests**

Run: `swift test 2>&1 | tail -5`
Expected: 17 tests pass

**Step 5: Commit**

```bash
git add Sources/HushCore/MonitorState.swift Tests/HushTests/MonitorStateTests.swift
git commit -m "fix: only trigger volumeRestored from dimmed state"
```

---

## Task 4: Replace MediaRemoteBridge with AppleScript (Bugs #1 & #2)

**Files:**
- Modify: `Sources/HushCore/MediaRemoteBridge.swift` (complete rewrite)

This is the core fix. The entire MediaRemote private framework approach is replaced with direct AppleScript queries to Spotify. This eliminates both the removed symbol (Bug #1) and the code-signing restriction (Bug #2).

**Step 1: Rewrite MediaRemoteBridge**

```swift
// MediaRemoteBridge.swift — full file
import Foundation

/// Fetches Spotify's Now Playing metadata via AppleScript.
///
/// macOS 26 restricts MediaRemote private framework access to Apple-signed
/// binaries, so we query Spotify directly instead.
public final class MediaRemoteBridge {
    public static let shared = MediaRemoteBridge()

    private let script: NSAppleScript?

    private static let appleScriptSource = """
        tell application "System Events"
            if not (exists process "Spotify") then return "NOT_RUNNING"
        end tell
        tell application "Spotify"
            if player state is stopped then return "STOPPED"
            set trackName to name of current track
            set trackArtist to artist of current track
            set trackAlbum to album of current track
            set trackURL to spotify url of current track
            set pState to player state as string
            return trackName & "\\n" & trackArtist & "\\n" & trackAlbum & "\\n" & trackURL & "\\n" & pState
        end tell
        """

    private init() {
        script = NSAppleScript(source: Self.appleScriptSource)
    }

    public func registerForNotifications() {
        // No-op: polling replaces notification-based monitoring
    }

    /// Get current Now Playing info. Calls completion synchronously with the result.
    public func getNowPlayingInfo(completion: @escaping (NowPlayingMetadata?) -> Void) {
        guard let script = script else {
            completion(nil)
            return
        }

        var error: NSDictionary?
        let result = script.executeAndReturnError(&error)

        if error != nil {
            completion(nil)
            return
        }

        guard let output = result.stringValue else {
            completion(nil)
            return
        }

        if output == "NOT_RUNNING" || output == "STOPPED" {
            completion(nil)
            return
        }

        let parts = output.components(separatedBy: "\n")
        guard parts.count >= 5 else {
            completion(nil)
            return
        }

        let title = parts[0]
        let artist = parts[1]
        let album = parts[2]
        let spotifyURL = parts[3]
        let playerState = parts[4]
        let isPlaying = playerState == "playing"
        let isAdByURL = spotifyURL.hasPrefix("spotify:ad:")

        let metadata = NowPlayingMetadata(
            title: title,
            artist: artist,
            album: album,
            bundleID: "com.spotify.client",
            playbackRate: isPlaying ? 1.0 : 0.0,
            isAdByURL: isAdByURL
        )
        completion(metadata)
    }
}
```

Key design decisions:
- `registerForNotifications()` kept as no-op so `MediaMonitor.start()` still compiles (cleaned up in Task 5)
- `getNowPlayingInfo` keeps the completion-handler signature so `MediaMonitor.checkNowPlaying()` doesn't need signature changes
- Bundle ID is hardcoded to `com.spotify.client` since we're querying Spotify directly
- `spotify:ad:` URL prefix provides reliable ad detection that doesn't depend on title/artist heuristics

**Step 2: Build**

Run: `swift build 2>&1 | tail -5`
Expected: Build succeeded

**Step 3: Run tests**

Run: `swift test 2>&1 | tail -5`
Expected: 17 tests pass (MediaRemoteBridge isn't unit-tested — it's an I/O boundary)

**Step 4: Commit**

```bash
git add Sources/HushCore/MediaRemoteBridge.swift
git commit -m "feat: replace MediaRemote private API with AppleScript

macOS 26 blocks MediaRemote for non-Apple-signed binaries and removed
the bundle ID symbol. Query Spotify directly via AppleScript instead."
```

---

## Task 5: Switch MediaMonitor from notifications to polling

**Files:**
- Modify: `Sources/HushCore/MediaMonitor.swift`

Notification-based monitoring via `MRMediaRemoteRegisterForNowPlayingNotifications` no longer fires on macOS 26. Replace with a 2-second poll timer.

**Step 1: Rewrite MediaMonitor**

```swift
// MediaMonitor.swift — full file
import Combine
import Foundation

public final class MediaMonitor: ObservableObject {
    @Published public private(set) var state: MonitorState = .idle
    @Published public private(set) var currentMetadata: NowPlayingMetadata?
    @Published public private(set) var isEnabled: Bool = true

    private let classifier: AdClassifier
    private let volumeController: VolumeController
    private let bridge: MediaRemoteBridge
    private var restoreTarget: Float = 0.5
    private var pollTimer: Timer?
    private static let pollInterval: TimeInterval = 2.0

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
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: Self.pollInterval, repeats: true) { [weak self] _ in
            guard let self = self, self.isEnabled else { return }
            self.checkNowPlaying()
        }

        // Listen for external volume changes while dimmed
        volumeController.onExternalVolumeChange { [weak self] newVolume in
            guard let self = self, self.state == .dimmed else { return }
            self.restoreTarget = newVolume
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
```

Key changes from `main`:
- **Notification -> polling:** Removed `NotificationCenter` observers and `@objc nowPlayingChanged`. Added `pollTimer` firing every 2s.
- **`restoreTarget` replaces `previousVolume`** (Bug #4 fix): `dimVolume()` writes to `restoreTarget`, `restoreVolume()` reads from `restoreTarget`. The `onExternalVolumeChange` callback also writes to `restoreTarget`. The CoreAudio property listener can no longer corrupt the restore value because `VolumeController.onExternalVolumeChange` only fires when `!isAdjusting` — but even if it did fire spuriously, it writes to `restoreTarget` which is the correct field.
- **Volume floor default:** `0.05` -> `0.0625` (one macOS volume step above zero).
- **No diagnostic logging:** The `debug/ad-detection` branch added `NSLog` and `os.log` statements for debugging. This clean implementation omits them.

**Step 2: Build**

Run: `swift build 2>&1 | tail -5`
Expected: Build succeeded

**Step 3: Run tests**

Run: `swift test 2>&1 | tail -5`
Expected: 17 tests pass

**Step 4: Commit**

```bash
git add Sources/HushCore/MediaMonitor.swift
git commit -m "fix: switch to polling and use separate restoreTarget

Notification-based monitoring no longer fires on macOS 26.
Poll every 2s via Timer instead.

Use dedicated restoreTarget field so the CoreAudio property listener
cannot overwrite the volume restore value (Bug A)."
```

---

## Task 6: Fix volume restore race condition in VolumeController (Bug #4)

**Files:**
- Modify: `Sources/HushCore/VolumeController.swift`

The race: `setVolume()` sets `isAdjusting = true`, calls `AudioObjectSetPropertyData`, sets `isAdjusting = false` — all synchronously. But the CoreAudio property listener fires *asynchronously* on `.main`. By the time it runs, `isAdjusting` is already `false`, so it looks like an external change.

Task 5 already isolated the restore target from the external change callback. This task adds defense-in-depth by debouncing the `isAdjusting` flag.

**Step 1: Add debounced isAdjusting reset**

In `VolumeController.swift`, modify the `setVolume` method:

```swift
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
    // Delay reset so the async property listener fires while isAdjusting is still true
    DispatchQueue.main.async { [weak self] in
        self?.isAdjusting = false
    }
}
```

The `DispatchQueue.main.async` ensures `isAdjusting` stays `true` through at least one run loop tick, which is when the CoreAudio listener fires.

Also update `fadeToVolume` — each intermediate `setVolume()` call now resets async, which is fine since `isAdjusting` is re-set to `true` on the next step before the async reset runs.

**Step 2: Build**

Run: `swift build 2>&1 | tail -5`
Expected: Build succeeded

**Step 3: Run tests**

Run: `swift test 2>&1 | tail -5`
Expected: 17 tests pass

**Step 4: Commit**

```bash
git add Sources/HushCore/VolumeController.swift
git commit -m "fix: debounce isAdjusting to prevent listener race condition

CoreAudio property listener fires async on .main after setVolume().
Delay isAdjusting reset to .main.async so the listener sees it as an
internal change and skips the callback."
```

---

## Task 7: Fix nested ObservableObject UI updates (Bug #5)

**Files:**
- Modify: `Sources/HushCore/AppState.swift`

SwiftUI only observes `AppState.objectWillChange`. When `MediaMonitor.state` changes, `AppState.objectWillChange` never fires because `monitor` is `let`, not `@Published`. The standard fix: subscribe to `monitor.objectWillChange` and forward it.

**Step 1: Add Combine forwarding**

```swift
// AppState.swift — full file
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

    public init() {
        let defaults = UserDefaults.standard
        // Register defaults
        defaults.register(defaults: [
            "isEnabled": true,
            "volumeFloor": Float(0.0625),
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

Changes:
- Added `private var monitorCancellable: AnyCancellable?`
- In `init()`, subscribe to `monitor.objectWillChange` and forward to `self.objectWillChange.send()`
- Volume floor default: `0.05` -> `0.0625`

**Step 2: Build**

Run: `swift build 2>&1 | tail -5`
Expected: Build succeeded

**Step 3: Run tests**

Run: `swift test 2>&1 | tail -5`
Expected: 17 tests pass

**Step 4: Commit**

```bash
git add Sources/HushCore/AppState.swift
git commit -m "fix: forward monitor changes to AppState for SwiftUI updates

SwiftUI only observes AppState.objectWillChange, not the nested
MediaMonitor. Subscribe and forward so isDimmed/statusText re-evaluate
when monitor state changes."
```

---

## Task 8: Final verification

**Step 1: Run full test suite**

Run: `swift test 2>&1`
Expected: 17 tests pass

**Step 2: Build release**

Run: `swift build -c release 2>&1 | tail -5`
Expected: Build succeeded

**Step 3: Verify diff is clean**

Run: `git diff main --stat`
Expected changes:
- `Sources/HushCore/AppState.swift` — Combine forwarding + volume floor
- `Sources/HushCore/MediaMonitor.swift` — polling + restoreTarget
- `Sources/HushCore/MediaRemoteBridge.swift` — AppleScript rewrite
- `Sources/HushCore/MonitorState.swift` — state machine fix
- `Sources/HushCore/NowPlayingMetadata.swift` — isAdByURL field
- `Sources/HushCore/SpotifyAdClassifier.swift` — URL-based detection
- `Sources/HushCore/VolumeController.swift` — isAdjusting debounce
- `Tests/HushTests/MonitorStateTests.swift` — updated expectations
- `Tests/HushTests/SpotifyAdClassifierTests.swift` — 2 new tests
- `docs/plans/2026-03-06-macos26-ad-detection-fix.md` — this plan

**Step 4: Commit plan**

```bash
git add docs/plans/2026-03-06-macos26-ad-detection-fix.md
git commit -m "docs: add implementation plan for macOS 26 ad detection fixes"
```

---

## Differences from `debug/ad-detection` branch

This plan produces a cleaner result than the debug branch:

| Aspect | `debug/ad-detection` | This plan |
|--------|---------------------|-----------|
| Diagnostic logging | `NSLog` + `os.log` throughout | None — clean production code |
| Volume restore bug (Bug A) | **Not fixed** — `previousVolume` still overwritable | Fixed via `restoreTarget` + `isAdjusting` debounce |
| UI update bug (Bug B) | **Not fixed** — nested ObservableObject | Fixed via Combine forwarding |
| Variable naming | `previousVolume` (misleading — gets overwritten) | `restoreTarget` (clear intent) |
| Debug branch artifacts | Leftover logging, `error` variable shadowing | Clean, minimal changes |
