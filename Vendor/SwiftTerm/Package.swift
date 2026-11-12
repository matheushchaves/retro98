// swift-tools-version:5.9
// SwiftTerm 1.11.2, vendored for Retro98 (see VENDORED.md). Its own warnings are not ours to fix.
import PackageDescription

let package = Package(
    name: "SwiftTerm",
    platforms: [.macOS(.v13)],
    products: [.library(name: "SwiftTerm", targets: ["SwiftTerm"])],
    targets: [
        .target(
            name: "SwiftTerm",
            path: "Sources/SwiftTerm",
            exclude: ["Mac/README.md"],
            swiftSettings: [.unsafeFlags(["-suppress-warnings"])]
        ),
    ]
)
