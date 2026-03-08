# Hush

A lightweight macOS menu bar app that automatically reduces system volume when Spotify plays ads, then restores it when music resumes.

## Install

**Requirements:** macOS 13 (Ventura) or later, Spotify (free tier)

```bash
git clone https://github.com/enflory/hush.git
cd hush
make app
make install
```

This builds `Hush.app` and copies it to `/Applications`. Launch it from there — a music note icon will appear in your menu bar.

On first launch, macOS will ask you to grant Hush permission to control System Events and Spotify. Accept both prompts.

### Uninstall

Drag `/Applications/Hush.app` to the trash.

## How It Works

Hush polls Spotify metadata via AppleScript every 2 seconds. When Spotify switches from music to an advertisement (detected by `spotify:ad:` URL prefix or metadata patterns), the system volume is immediately reduced to a configurable floor level (default 5%). When music resumes, volume fades back to the previous level over ~1 second.

Volume is reduced, not muted, because Spotify detects muting and pauses playback.

## Settings

Click the music note icon in the menu bar to access:

- **On/Off toggle** -- Enable or disable ad detection
- **Ad volume slider** -- Set how quiet ads should be (1%-25%)
- **Launch at login** -- Start Hush automatically when you log in

## Development

```bash
swift build              # Build all targets
swift run Hush           # Run without installing
swift test               # Run all tests
make app                 # Build Hush.app bundle
make install             # Build and copy to /Applications
make clean               # Remove build/ directory
make icon                # Regenerate app icon from SF Symbol
```

## Architecture

```
Sources/
  HushCore/           # Library target (all business logic)
    AdClassifier.swift        # Protocol for ad detection
    SpotifyAdClassifier.swift # Spotify-specific ad detection
    MonitorState.swift        # State machine (idle/normal/dimmed)
    VolumeController.swift    # CoreAudio volume get/set/fade
    MediaRemoteBridge.swift   # AppleScript bridge to Spotify
    MediaMonitor.swift        # Orchestrator
    AppState.swift            # Settings + observable state
    NowPlayingMetadata.swift  # Metadata model
  Hush/               # Executable target (SwiftUI app)
    HushApp.swift             # Menu bar entry point
    SettingsView.swift        # Popover UI
Resources/
  Info.plist                  # App bundle metadata
  AppIcon.icns                # App icon
scripts/
  build-app.sh                # Assembles and codesigns .app bundle
  generate-icon.swift         # Generates AppIcon.icns from SF Symbol
Tests/
  HushTests/          # Unit tests
```

## License

MIT
