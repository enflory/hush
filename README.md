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

Hush polls Spotify metadata via AppleScript every 2 seconds. When Spotify switches from music to an advertisement (detected by `spotify:ad:` URL prefix or metadata patterns), the system volume is immediately reduced to a configurable floor level (default 5%). When music resumes, volume fades back to the previous level over ~1 second.

Volume is reduced, not muted, because Spotify detects muting and pauses playback.

## Settings

Click the speaker icon in the menu bar to access:

- **On/Off toggle** -- Enable or disable ad detection
- **Ad volume slider** -- Set how quiet ads should be (1%-25%)
- **Launch at login** -- Start Hush automatically when you log in

## Architecture

```
Sources/
  HushCore/           # Library target (all business logic)
    AdClassifier.swift        # Protocol for ad detection
    SpotifyAdClassifier.swift # Spotify-specific ad detection
    MonitorState.swift        # State machine (idle/normal/dimmed)
    VolumeController.swift    # CoreAudio volume get/set/fade
    MediaRemoteBridge.swift   # Private framework bridge
    MediaMonitor.swift        # Orchestrator
    AppState.swift            # Settings + observable state
    NowPlayingMetadata.swift  # Metadata model
  Hush/               # Executable target (SwiftUI app)
    HushApp.swift             # Menu bar entry point
    SettingsView.swift        # Popover UI
Tests/
  HushTests/          # Unit tests
```

## License

MIT
