# Hush .app Bundle — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Produce a standard macOS `.app` bundle so Hush can be dragged to `/Applications`, double-clicked to launch, and register login items via SMAppService.

**Architecture:** A build script compiles the SPM binary, assembles a `.app` bundle directory structure with Info.plist and an app icon, then ad-hoc codesigns it. A Makefile wraps the script for convenience.

**Tech Stack:** Swift Package Manager, `codesign`, `iconutil`, AppKit (icon generation only)

---

## Context

Hush currently runs via `swift build && swift run Hush`. The "Launch at Login" toggle uses `SMAppService`, which requires a proper `.app` bundle with a `CFBundleIdentifier` — it silently fails without one. The app is menu-bar-only (`.accessory` activation policy).

Key constraints:
- `SMAppService.mainApp.register()` requires the app to be in `/Applications` or `~/Applications`
- Ad-hoc codesigning is sufficient for local use; Developer ID needed only for distribution
- The app uses AppleScript to query both System Events and Spotify — macOS shows a separate permission prompt for each

---

### Task 1: Create `Resources/Info.plist`

**Files:**
- Create: `Resources/Info.plist`

**Step 1: Create the Resources directory and Info.plist**

```bash
mkdir -p Resources
```

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>com.hush.app</string>
    <key>CFBundleExecutable</key>
    <string>Hush</string>
    <key>CFBundleName</key>
    <string>Hush</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSAppleEventsUsageDescription</key>
    <string>Hush uses AppleScript to detect when Spotify is playing an ad so it can reduce the volume.</string>
</dict>
</plist>
```

**Step 2: Verify the plist is valid**

Run: `plutil -lint Resources/Info.plist`
Expected: `Resources/Info.plist: OK`

**Step 3: Commit**

```bash
git add Resources/Info.plist
git commit -m "feat: add Info.plist for .app bundle"
```

---

### Task 2: Generate App Icon

**Files:**
- Create: `scripts/generate-icon.swift`
- Create: `Resources/AppIcon.icns` (generated output, committed to repo)

**Step 1: Create the scripts directory and icon generation script**

```bash
mkdir -p scripts
```

Write `scripts/generate-icon.swift`:

```swift
#!/usr/bin/env swift
import AppKit
import Foundation

let symbolName = "speaker.slash.fill"
let iconsetDir = "Resources/AppIcon.iconset"
let outputPath = "Resources/AppIcon.icns"

let fm = FileManager.default
try? fm.removeItem(atPath: iconsetDir)
try fm.createDirectory(atPath: iconsetDir, withIntermediateDirectories: true)

// macOS iconset requires these exact filenames and pixel sizes
let variants: [(String, Int)] = [
    ("icon_16x16",      16),
    ("icon_16x16@2x",   32),
    ("icon_32x32",      32),
    ("icon_32x32@2x",   64),
    ("icon_128x128",    128),
    ("icon_128x128@2x", 256),
    ("icon_256x256",    256),
    ("icon_256x256@2x", 512),
    ("icon_512x512",    512),
    ("icon_512x512@2x", 1024),
]

for (name, px) in variants {
    let size = NSSize(width: px, height: px)
    let image = NSImage(size: size)
    image.lockFocus()

    let rect = NSRect(origin: .zero, size: size)
    let cornerRadius = CGFloat(px) * 0.22

    // Dark rounded-rect background
    let path = NSBezierPath(roundedRect: rect.insetBy(dx: 1, dy: 1),
                            xRadius: cornerRadius, yRadius: cornerRadius)
    NSColor(red: 0.13, green: 0.13, blue: 0.18, alpha: 1).setFill()
    path.fill()

    // Render SF Symbol centered in white
    let pointSize = CGFloat(px) * 0.45
    let config = NSImage.SymbolConfiguration(pointSize: pointSize, weight: .medium)
    if let symbol = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)?
        .withSymbolConfiguration(config) {
        let symSize = symbol.size
        let origin = NSPoint(x: (CGFloat(px) - symSize.width) / 2,
                             y: (CGFloat(px) - symSize.height) / 2)
        let symRect = NSRect(origin: origin, size: symSize)

        // Draw symbol then tint white via sourceAtop
        symbol.draw(in: symRect, from: .zero, operation: .sourceOver, fraction: 1)
        NSColor.white.set()
        symRect.fill(using: .sourceAtop)
    }

    image.unlockFocus()

    guard let tiff = image.tiffRepresentation,
          let rep  = NSBitmapImageRep(data: tiff),
          let png  = rep.representation(using: .png, properties: [:]) else {
        fputs("Failed to create PNG for \(name)\n", stderr)
        exit(1)
    }
    try png.write(to: URL(fileURLWithPath: "\(iconsetDir)/\(name).png"))
}

// Convert iconset → icns
let proc = Process()
proc.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
proc.arguments = ["-c", "icns", iconsetDir, "-o", outputPath]
try proc.run()
proc.waitUntilExit()

guard proc.terminationStatus == 0 else {
    fputs("iconutil failed with status \(proc.terminationStatus)\n", stderr)
    exit(1)
}

// Clean up intermediate iconset directory
try? fm.removeItem(atPath: iconsetDir)
print("✓ Created \(outputPath)")
```

**Step 2: Run the script to generate the icon**

Run: `swift scripts/generate-icon.swift`
Expected: `✓ Created Resources/AppIcon.icns`

Verify: `file Resources/AppIcon.icns`
Expected: `Resources/AppIcon.icns: Mac OS X icon, ...`

If the icon looks wrong (check in Finder: `open -R Resources/AppIcon.icns`), adjust colors/sizing in the script and re-run.

**Step 3: Commit**

```bash
git add scripts/generate-icon.swift Resources/AppIcon.icns
git commit -m "feat: add app icon generated from SF Symbol"
```

---

### Task 3: Create Build Script

**Files:**
- Create: `scripts/build-app.sh`

**Step 1: Write the build script**

```bash
#!/bin/bash
set -euo pipefail

APP_NAME="Hush"
BUILD_DIR="build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
CONTENTS="$APP_BUNDLE/Contents"

echo "Building $APP_NAME..."
swift build -c release

BIN_PATH=$(swift build -c release --show-bin-path)

echo "Assembling $APP_NAME.app..."
rm -rf "$APP_BUNDLE"
mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources"

cp "$BIN_PATH/$APP_NAME"       "$CONTENTS/MacOS/$APP_NAME"
cp Resources/Info.plist        "$CONTENTS/Info.plist"
cp Resources/AppIcon.icns      "$CONTENTS/Resources/AppIcon.icns"

echo "Code signing (ad-hoc)..."
codesign --force --sign - "$APP_BUNDLE"

echo ""
echo "Built: $APP_BUNDLE"
echo "To install: cp -R $APP_BUNDLE /Applications/"
```

**Step 2: Make it executable**

Run: `chmod +x scripts/build-app.sh`

**Step 3: Run the build script**

Run: `./scripts/build-app.sh`
Expected: prints "Built: build/Hush.app" without errors.

Verify the bundle structure:

Run: `find build/Hush.app -type f`
Expected:
```
build/Hush.app/Contents/Info.plist
build/Hush.app/Contents/MacOS/Hush
build/Hush.app/Contents/Resources/AppIcon.icns
```

**Step 4: Commit**

```bash
git add scripts/build-app.sh
git commit -m "feat: add build script for .app bundle"
```

---

### Task 4: Create Makefile

**Files:**
- Create: `Makefile`

**Step 1: Write the Makefile**

```makefile
.PHONY: app install clean icon

app:
	./scripts/build-app.sh

install: app
	cp -R build/Hush.app /Applications/
	@echo "Installed to /Applications/Hush.app"

clean:
	rm -rf build

icon:
	swift scripts/generate-icon.swift
```

**Step 2: Verify targets**

Run: `make clean && make app`
Expected: builds successfully, produces `build/Hush.app`

**Step 3: Commit**

```bash
git add Makefile
git commit -m "feat: add Makefile (app, install, clean, icon)"
```

---

### Task 5: Update .gitignore and CLAUDE.md

**Files:**
- Modify: `.gitignore`
- Modify: `CLAUDE.md`

**Step 1: Add `build/` to .gitignore**

The `.gitignore` already has `.build/` (SPM output). Add `build/` (our .app bundle output directory) so it doesn't get committed:

```
build/
```

**Step 2: Update CLAUDE.md build commands**

Add to the build commands section:

```bash
make app                 # Build Hush.app bundle (output: build/Hush.app)
make install             # Build and copy to /Applications
make clean               # Remove build/ directory
make icon                # Regenerate AppIcon.icns from SF Symbol
```

**Step 3: Verify tests still pass**

Run: `swift test`
Expected: 20 tests pass (no source changes in this plan)

**Step 4: Commit**

```bash
git add .gitignore CLAUDE.md
git commit -m "chore: update .gitignore and CLAUDE.md for app bundle"
```

---

### Task 6: End-to-End Verification

**Step 1: Clean build from scratch**

Run: `make clean && make app`
Expected: `build/Hush.app` created successfully

**Step 2: Verify bundle contents**

Run: `plutil -lint build/Hush.app/Contents/Info.plist`
Expected: OK

Run: `codesign -vv build/Hush.app`
Expected: `build/Hush.app: valid on disk`

**Step 3: Launch the app**

Run: `open build/Hush.app`
Expected: Menu bar icon appears (music note), popover works, no dock icon

**Step 4: Install and test login item**

Run: `make install`
Then: Open the app from `/Applications/Hush.app`, toggle "Launch at Login" — should succeed without errors in Console.app

**Step 5: Verify tests unchanged**

Run: `swift test`
Expected: All 20 tests pass

---

## Files Summary

| File | Action |
|------|--------|
| `Resources/Info.plist` | Create |
| `Resources/AppIcon.icns` | Create (generated) |
| `scripts/generate-icon.swift` | Create |
| `scripts/build-app.sh` | Create |
| `Makefile` | Create |
| `.gitignore` | Modify (add `build/`) |
| `CLAUDE.md` | Modify (add bundle build commands) |

## Notes

- **SMAppService requires `/Applications`**: The login item toggle only works when the app is installed to `/Applications` or `~/Applications`. Running from `build/` will fail silently.
- **AppleScript permissions**: On first launch, macOS will prompt the user to allow Hush to control System Events and Spotify. Both must be granted.
- **No source code changes**: This plan only adds build infrastructure. All 20 existing tests remain unchanged.
- **Ad-hoc signing**: Sufficient for local use. Distribution (DMG, notarization) would require an Apple Developer ID — out of scope for this plan.
