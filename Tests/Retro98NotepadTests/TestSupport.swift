import AppKit
@testable import Retro98Notepad

/// The repository root, from this file's location.
let repoRoot = URL(filePath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

/// A fresh folder under the system's temporary directory; tests remove it when done.
func temporaryFolder() throws -> URL {
    let url = FileManager.default.temporaryDirectory.appending(path: "retro98-notepad-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}
