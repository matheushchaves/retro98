// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Retro98",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "Retro98Settings", targets: ["Retro98Settings"]),
        .library(name: "Retro98UI", targets: ["Retro98UI"]),
        .library(name: "Retro98ShellCore", targets: ["Retro98ShellCore"]),
        .library(name: "Retro98FilesCore", targets: ["Retro98FilesCore"]),
        .executable(name: "retro98-settings", targets: ["retro98-settings"]),
        .executable(name: "Retro98Shell", targets: ["Retro98Shell"]),
        .executable(name: "Retro98Explorer", targets: ["Retro98Explorer"]),
        .executable(name: "retro98-tools", targets: ["retro98-tools"]),
    ],
    targets: [
        .target(name: "Retro98Settings"),
        .executableTarget(name: "retro98-settings", dependencies: ["Retro98Settings"]),
        .testTarget(name: "Retro98SettingsTests", dependencies: ["Retro98Settings"]),
        .target(name: "Retro98UI"),
        .testTarget(name: "Retro98UITests", dependencies: ["Retro98UI"]),
        .target(name: "Retro98ShellCore", dependencies: ["Retro98Settings", "Retro98FilesCore"]),
        .testTarget(name: "Retro98ShellCoreTests", dependencies: ["Retro98ShellCore", "Retro98Settings"]),
        .target(name: "Retro98FilesCore", dependencies: ["Retro98Settings"]),
        .testTarget(name: "Retro98FilesCoreTests", dependencies: ["Retro98FilesCore", "Retro98Settings"]),
        .executableTarget(name: "retro98-tools", dependencies: ["Retro98UI"]),
        .executableTarget(name: "Retro98Explorer", dependencies: ["Retro98UI", "Retro98FilesCore", "Retro98Settings"]),
        .testTarget(name: "Retro98ExplorerTests", dependencies: ["Retro98Explorer", "Retro98FilesCore", "Retro98UI"]),
        .executableTarget(name: "Retro98Shell", dependencies: ["Retro98UI", "Retro98ShellCore", "Retro98Settings"]),
    ]
)
