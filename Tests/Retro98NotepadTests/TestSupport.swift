import AppKit
import Retro98UI
@testable import Retro98Notepad

/// The repository root, from this file's location.
let repoRoot = URL(filePath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

/// A fresh folder under the system's temporary directory; tests remove it when done.
func temporaryFolder() throws -> URL {
    let url = FileManager.default.temporaryDirectory.appending(path: "retro98-notepad-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

let vgaFontURL = repoRoot.appending(path: "Resources/Fonts/PxPlus_IBM_VGA_8x16.ttf")

/// Answers "save the changes?" from a queue (Cancel when it runs out) and records every message.
@MainActor final class ScriptedNotepadPrompter: NotepadPrompter {
    var answers: [SaveAnswer] = []
    var asked: [String] = []
    var told: [String] = []

    func askToSave(_ message: String, languages: [String]) -> SaveAnswer {
        asked.append(message)
        return answers.isEmpty ? .cancel : answers.removeFirst()
    }

    func tell(_ message: String, icon: MessageBoxIcon, languages: [String]) { told.append(message) }
}

/// Hands out queued files instead of showing dialogs (nil, a cancel, when the queue is empty).
@MainActor final class ScriptedNotepadDialogs: NotepadDialogs {
    var opens: [URL?] = []
    var saves: [URL?] = []
    var openFolders: [URL] = []
    var saveRequests: [(folder: URL, name: String)] = []

    func chooseFileToOpen(in folder: URL, languages: [String]) -> URL? {
        openFolders.append(folder)
        return opens.isEmpty ? nil : opens.removeFirst()
    }

    func chooseSaveLocation(in folder: URL, name: String, languages: [String]) -> URL? {
        saveRequests.append((folder, name))
        return saves.isEmpty ? nil : saves.removeFirst()
    }
}

/// Draws the view at 2× and counts the distinct RGB colors in its top `rows` text rows (16 pt each).
/// Crisp text has only the background and the colors in use; font smoothing adds dozens of shades.
@MainActor func distinctColors(_ view: NSView, rows: Int) -> Int {
    let size = view.bounds.size
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: Int(size.width) * 2, pixelsHigh: Int(size.height) * 2, bitsPerSample: 8,
        samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    ) else { return 0 }
    rep.size = size
    view.cacheDisplay(in: view.bounds, to: rep)
    guard let data = rep.bitmapData else { return 0 }
    var colors = Set<UInt32>()
    for y in 0..<min(rows * 32, rep.pixelsHigh) {
        for x in 0..<rep.pixelsWide {
            let i = y * rep.bytesPerRow + x * 4
            colors.insert(UInt32(data[i]) << 16 | UInt32(data[i + 1]) << 8 | UInt32(data[i + 2]))
        }
    }
    return colors.count
}
