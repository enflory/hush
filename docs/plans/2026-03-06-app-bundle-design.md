# Plan: Build Script for Hush .app Bundle

## Context

Hush is currently launched via `swift build && swift run Hush`, which is developer-friendly but not user-friendly. The app also has a "Launch at Login" toggle that uses `SMAppService`, which requires a proper `.app` bundle to function. This plan creates a build script that produces a standard macOS `.app` bundle you can drag to `/Applications` and double-click to launch.

## What We're Creating

### 1. `Info.plist` template — `Resources/Info.plist`

Required keys:
- `CFBundleIdentifier`: `com.hush.app` (needed for SMAppService)
- `CFBundleExecutable`: `Hush`
- `CFBundleName`: `Hush`
- `CFBundlePackageType`: `APPL`
- `CFBundleVersion`: `1.0`
- `CFBundleShortVersionString`: `1.0`
- `LSMinimumSystemVersion`: `13.0`
- `LSUIElement`: `true` (menu bar-only, no dock icon — backup for the programmatic `setActivationPolicy(.accessory)`)
- `NSAppleEventsUsageDescription`: Explanation that Hush needs AppleScript access to detect Spotify ads (triggers macOS permission prompt on first run)

### 2. Build script — `scripts/build-app.sh`

Steps the script performs:
1. `swift build -c release` — compile the binary
2. Create `.app` bundle directory structure:
   ```
   build/Hush.app/
   └── Contents/
       ├── Info.plist
       ├── MacOS/
       │   └── Hush          (copied from .build/release/)
       └── Resources/
   ```
3. Copy `Info.plist` from `Resources/Info.plist` into bundle
4. Copy compiled binary into `Contents/MacOS/`
5. Ad-hoc code sign: `codesign --force --sign - build/Hush.app` (required for SMAppService to register login items)
6. Print success message with instructions to copy to `/Applications`

### 3. App icon — `Resources/AppIcon.icns`

Generate a simple app icon for Hush so it has a proper icon in `/Applications` and Finder:
- Design concept: a speaker symbol with a "shush" gesture or muted indicator, matching the app's purpose
- Create a 1024x1024 source PNG using a script that invokes `sips` and `iconutil` to produce an `.icns` file from an `AppIcon.iconset/` directory (containing required sizes: 16, 32, 128, 256, 512 @1x and @2x)
- Reference the icon in `Info.plist` via `CFBundleIconFile: AppIcon`
- The build script copies `AppIcon.icns` into `Contents/Resources/` in the bundle

For the source image, options:
- **SF Symbols export**: Use an SF Symbol (e.g., `speaker.slash.fill`) rendered to PNG via a small Swift script or `NSImage` export
- **Hand-drawn SVG → PNG**: Create a minimal SVG and convert with `sips`
- **Pre-made PNG**: Use a simple design created programmatically

Recommended: Export an SF Symbol (`speaker.slash.fill`) to PNG at 1024x1024 via a small Swift helper script in `scripts/`, then convert to `.icns`. This keeps the icon consistent with the menu bar icon style.

### 4. `Makefile` (convenience wrapper)

```
make app      → runs the build script
make install  → copies Hush.app to /Applications
make clean    → removes build/ directory
```

## Files to Create/Modify

| File | Action |
|------|--------|
| `Resources/Info.plist` | Create (add `CFBundleIconFile: AppIcon`) |
| `Resources/AppIcon.icns` | Create (generated from SF Symbol) |
| `scripts/generate-icon.swift` | Create (Swift script to export SF Symbol to iconset) |
| `scripts/build-app.sh` | Create |
| `Makefile` | Create |
| `CLAUDE.md` | Update build commands section |

## Branch

All work on branch `feature/app-bundle`.

## Verification

1. Run `make app` — should produce `build/Hush.app`
2. Double-click `build/Hush.app` — app should launch as menu bar icon
3. Run `make install` — should copy to `/Applications`
4. Toggle "Launch at Login" in the app — should succeed (no error in console)
5. Restart Mac — app should auto-launch if toggle was on
6. `swift test` — should still pass (no source changes)
