// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Retro98",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "Retro98Settings", targets: ["Retro98Settings"]),
        .library(name: "Retro98Screensavers", targets: ["Retro98Screensavers"]),
        .library(name: "Retro98UI", targets: ["Retro98UI"]),
        .library(name: "Retro98ShellCore", targets: ["Retro98ShellCore"]),
        .library(name: "Retro98FilesCore", targets: ["Retro98FilesCore"]),
        .library(name: "Retro98Dialogs", targets: ["Retro98Dialogs"]),
        .library(name: "Retro98Themes", targets: ["Retro98Themes"]),
        .executable(name: "retro98-settings", targets: ["retro98-settings"]),
        .executable(name: "Retro98Shell", targets: ["Retro98Shell"]),
        .executable(name: "Retro98Explorer", targets: ["Retro98Explorer"]),
        .executable(name: "retro98-tools", targets: ["retro98-tools"]),
        .executable(name: "Retro98Prompt", targets: ["Retro98Prompt"]),
        .executable(name: "Retro98ControlPanel", targets: ["Retro98ControlPanel"]),
        .executable(name: "Retro98Notepad", targets: ["Retro98Notepad"]),
        .executable(name: "Retro98Browser", targets: ["Retro98Browser"]),
    ],
    // SwiftTerm stays vendored at 1.11.2: 1.12+ needs Xcode's Metal Toolchain to build (see Vendor/SwiftTerm/VENDORED.md).
    dependencies: [
        .package(path: "Vendor/SwiftTerm"),
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
        .target(name: "Retro98Themes", dependencies: ["Retro98UI"]),
        .testTarget(name: "Retro98ThemesTests", dependencies: ["Retro98Themes", "Retro98UI"]),
        .executableTarget(name: "retro98-tools", dependencies: ["Retro98UI", "Retro98Themes"]),
        .target(name: "Retro98Dialogs", dependencies: ["Retro98UI", "Retro98FilesCore", "Retro98Settings"]),
        .testTarget(name: "Retro98DialogsTests", dependencies: ["Retro98Dialogs", "Retro98FilesCore", "Retro98UI"]),
        .executableTarget(name: "Retro98Explorer", dependencies: ["Retro98UI", "Retro98FilesCore", "Retro98Settings", "Retro98Dialogs"],
                          swiftSettings: [.enableExperimentalFeature("IsolatedDeinit")]),
        .testTarget(name: "Retro98ExplorerTests", dependencies: ["Retro98Explorer", "Retro98FilesCore", "Retro98UI"],
                    swiftSettings: [.enableExperimentalFeature("IsolatedDeinit")]),
        .target(name: "Retro98Screensavers", dependencies: ["Retro98UI", "Retro98Settings"]),
        .testTarget(name: "Retro98ScreensaversTests", dependencies: ["Retro98Screensavers", "Retro98Settings"]),
        .executableTarget(name: "Retro98Shell", dependencies: ["Retro98UI", "Retro98ShellCore", "Retro98Settings", "Retro98Screensavers"]),
        .executableTarget(
            name: "Retro98Prompt",
            dependencies: ["Retro98UI", "Retro98Settings", .product(name: "SwiftTerm", package: "SwiftTerm")]
        ),
        .executableTarget(name: "Retro98ControlPanel", dependencies: ["Retro98UI", "Retro98Settings", "Retro98Screensavers"]),
        .testTarget(name: "Retro98ControlPanelTests", dependencies: ["Retro98ControlPanel", "Retro98Settings", "Retro98UI"]),
        .executableTarget(name: "Retro98Notepad", dependencies: ["Retro98UI", "Retro98FilesCore", "Retro98Settings", "Retro98Dialogs"]),
        .testTarget(name: "Retro98NotepadTests", dependencies: ["Retro98Notepad", "Retro98UI", "Retro98Dialogs"]),
        .executableTarget(name: "Retro98Browser", dependencies: ["Retro98UI", "Retro98FilesCore", "Retro98Settings", "Retro98Dialogs"]),
        .testTarget(name: "Retro98BrowserTests", dependencies: ["Retro98Browser", "Retro98UI"]),
        .testTarget(
            name: "Retro98PromptTests",
            dependencies: ["Retro98Prompt", "Retro98UI", .product(name: "SwiftTerm", package: "SwiftTerm")]
        ),
    ]
)
