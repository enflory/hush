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
