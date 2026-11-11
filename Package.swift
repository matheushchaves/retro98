// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Retro98",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "Retro98Settings", targets: ["Retro98Settings"]),
        .library(name: "Retro98UI", targets: ["Retro98UI"]),
        .executable(name: "retro98-settings", targets: ["retro98-settings"]),
    ],
    targets: [
        .target(name: "Retro98Settings"),
        .executableTarget(name: "retro98-settings", dependencies: ["Retro98Settings"]),
        .testTarget(name: "Retro98SettingsTests", dependencies: ["Retro98Settings"]),
        .target(name: "Retro98UI"),
        .testTarget(name: "Retro98UITests", dependencies: ["Retro98UI"]),
    ]
)
