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
