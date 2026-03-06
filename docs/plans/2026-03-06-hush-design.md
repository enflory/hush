# Hush - Ad Volume Reducer for macOS

## Problem

Spotify Free plays ads at a noticeably louder volume than music. Muting triggers Spotify to pause playback. Users need a way to automatically reduce (not mute) volume during ads and restore it when music resumes.

## Solution

A lightweight macOS menu bar app that monitors Now Playing metadata via Apple's private MediaRemote framework, detects Spotify ads, and reduces system volume to a configurable floor level. When music resumes, volume fades back to the previous level.

## Architecture

Swift + SwiftUI menu bar app. No dock icon, no window (`LSUIElement = true`). Targets macOS 13 (Ventura)+.

### Components

- **AppDelegate** - Sets up menu bar item, manages popover lifecycle
- **MediaMonitor** - Subscribes to MediaRemote Now Playing notifications, classifies tracks using AdClassifier protocol
- **VolumeController** - Gets/sets system volume via CoreAudio, handles fade-in restore
- **SettingsView** (SwiftUI) - Popover UI with controls

### Ad Detection

Uses Apple's private MediaRemote framework:
- Dynamically loads `/System/Library/PrivateFrameworks/MediaRemote.framework`
- Registers for `kMRMediaRemoteNowPlayingInfoDidChangeNotification`
- Calls `MRMediaRemoteGetNowPlayingInfo` to read metadata on change

**AdClassifier protocol:**
```swift
protocol AdClassifier {
    func isAd(metadata: NowPlayingMetadata) -> Bool
}
```

**SpotifyAdClassifier** identifies ads when source is `com.spotify.client` and:
- Title is "Advertisement" or "Spotify"
- Artist is empty or "Spotify"
- Album is empty or "Spotify"

Extensible to other media sources by adding new classifier implementations.

### State Machine

```
         Spotify starts
Idle ──────────────────────▶ Normal
  ▲                           │  ▲
  │ Spotify closes            │  │ music resumes
  └───────────────────────────┘  │
                            ad   │
                         detected│
                              ▼  │
                            Dimmed
```

- **Idle** - Spotify not playing, no action
- **Normal** - Music playing, volume untouched
- **Dimmed** - Ad detected, volume reduced to floor

### Volume Control

CoreAudio `AudioObjectGetPropertyData` / `AudioObjectSetPropertyData` on `kAudioHardwareServiceDeviceProperty_VirtualMainVolume`. Volume is Float32 (0.0-1.0).

**Reduction:** Immediate drop to floor (default 5%) when ad detected. No fade-out.

**Restore:** Fade from floor to `previousVolume` over ~1 second using Timer (50ms interval, ~20 steps). Cancels if new ad starts during fade.

**User volume change during ad:** `AudioObjectAddPropertyListenerBlock` monitors volume changes. If user changes volume while dimmed (and we didn't cause it), update `previousVolume` to their new value.

### Edge Cases

- User changes volume during ad: restore to new user-set volume, not stale saved value
- Spotify paused during ad: stay dimmed until music resumes
- App launched mid-ad: check current metadata on startup, not just on change

### Menu Bar UI

**Icon:** SF Symbol - `speaker.slash` when dimming, `speaker.wave.2` when normal/idle

**Popover contents:**
- On/Off toggle (enables/disables detection, keeps app running)
- Status line ("Listening", "Ad detected - volume dimmed", "Disabled")
- Volume floor slider (1%-25%, default 5%)
- Launch at login toggle (via SMAppService)
- Quit button

### Settings Persistence

All settings stored in UserDefaults:
- `isEnabled` (Bool, default: true)
- `volumeFloor` (Float, default: 0.05)
- `launchAtLogin` (Bool, default: true)

## Non-Goals (MVP)

- YouTube / browser ad detection
- Per-app volume control (only system volume)
- Audio fingerprinting / content analysis
- App Store distribution
- iOS version
