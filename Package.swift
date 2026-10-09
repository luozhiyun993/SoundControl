// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "SoundControl",
    platforms: [.macOS("14.2")],
    targets: [
        .executableTarget(
            name: "SoundControl",
            path: "Sources/SoundControl"
        )
    ]
)
