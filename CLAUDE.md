# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Test Commands

```bash
swift build              # Build all targets
swift run Hush           # Build and run the app
swift test               # Run all tests (17 tests)
swift test --filter SpotifyAdClassifierTests   # Run ad classifier tests only
swift test --filter MonitorStateTests          # Run state machine tests only
```

## Project Overview

Hush is a macOS menu bar app (Swift/SwiftUI, macOS 13+) that detects Spotify ads and reduces system volume to a configurable floor, restoring it when music resumes. Volume is reduced (not muted) because Spotify detects muting and pauses playback.

## Architecture

Two SPM targets: **HushCore** (library with all business logic) and **Hush** (executable with SwiftUI entry point). Tests import HushCore — the split avoids `@main` conflicts.

### Data flow

```
AppleScript polling → MediaMonitor → AdClassifier → MonitorState → VolumeController
```

**MediaRemoteBridge** (singleton) queries Spotify directly via AppleScript (`NSAppleScript`) on a 2-second polling timer. Returns metadata (title, artist, album, Spotify URL, playback state). Originally used the private MediaRemote framework, but macOS 26 restricts it to Apple-signed binaries.

**MediaMonitor** is the orchestrator. On each poll, it fetches metadata from the bridge, classifies it, runs the state machine, and calls VolumeController. It's an `ObservableObject` so SwiftUI can react to state changes.

**MonitorState** is a value-type state machine with three states: `idle` (Spotify not playing), `normal` (music playing), `dimmed` (ad detected). The `transition()` method is a pure function that returns a `MonitorAction` (.volumeDimmed, .volumeRestored, .noChange).

**SpotifyAdClassifier** detects ads by checking bundle ID is `com.spotify.client` and either the Spotify URL has a `spotify:ad:` prefix or metadata matches ad patterns (title "Advertisement"/"Spotify", artist empty/"Spotify"). Conforms to `AdClassifier` protocol for extensibility to other sources.

**VolumeController** uses CoreAudio (`kAudioHardwareServiceDeviceProperty_VirtualMainVolume`) for system volume. Dim is instant; restore fades over ~1s via Timer.

**AppState** owns MediaMonitor, persists settings to UserDefaults (`isEnabled`, `volumeFloor`, `launchAtLogin`), manages login item via SMAppService.

### UI

Menu bar-only app (`NSApp.setActivationPolicy(.accessory)` in AppDelegate). Icon toggles between `speaker.wave.2` and `speaker.slash`. Popover uses `MenuBarExtra` with `.window` style.

## Key Conventions

- Tests use **Swift Testing** framework (`import Testing`, `@Test`, `#expect`), not XCTest
- All business logic lives in HushCore; Hush target only contains SwiftUI views and the `@main` entry point
- `NSApp.setActivationPolicy(.accessory)` must be called in `applicationDidFinishLaunching`, not in `App.init()` (NSApp is nil during init when run via `swift run`)
