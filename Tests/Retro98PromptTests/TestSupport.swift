import AppKit
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
