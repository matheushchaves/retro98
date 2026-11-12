import AppKit
import SwiftTerm
@testable import Retro98Prompt

/// The repository root, from this file's location.
let repoRoot = URL(filePath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
let vgaFontURL = repoRoot.appending(path: "Resources/Prompt/PxPlus_IBM_VGA_8x16.ttf")

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

/// /bin/sh with a throwaway home, no history file and no startup file, so tests never read or write the user's files.
func sh(_ arguments: [String], home: URL) -> ShellLaunch {
    let environment = ["HOME=\(home.path)", "HISTFILE=/dev/null", "PATH=/usr/bin:/bin:/usr/sbin:/sbin", "PS1=", "TERM=xterm-256color"]
    return ShellLaunch(executable: "/bin/sh", arguments: arguments, execName: "sh", environment: environment, directory: home.path)
}

/// Polls every 20 ms until `condition` holds or `seconds` pass; the main queue keeps running in between,
/// so the terminal reads its process meanwhile.
@MainActor func waitUntil(_ seconds: Double = 5, _ condition: () -> Bool) async -> Bool {
    let deadline = Date().addingTimeInterval(seconds)
    while !condition() {
        if Date() > deadline { return false }
        try? await Task.sleep(for: .milliseconds(20))
    }
    return true
}

/// The visible rows of the terminal, right-trimmed and joined by newlines.
@MainActor func screenText(_ view: TerminalView) -> String {
    let terminal = view.getTerminal()
    return (0..<terminal.rows).compactMap { terminal.getLine(row: $0)?.translateToString(trimRight: true) }.joined(separator: "\n")
}
