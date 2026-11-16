import AppKit
import Retro98UI
@testable import Retro98Browser

/// A fresh folder under the system's temporary directory; tests remove it when done.
func temporaryFolder() throws -> URL {
    let url = FileManager.default.temporaryDirectory.appending(path: "retro98-browser-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

func web(_ text: String) -> URL { URL(string: text)! }
