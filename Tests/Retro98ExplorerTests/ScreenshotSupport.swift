import AppKit

// The same file sits in each app's test target: test targets can't share code without a module of their own.

/// Where `scripts/make-screenshots.sh` wants the README images; unset in normal test runs, which skip these.
let screenshotFolder = ProcessInfo.processInfo.environment["RETRO98_SCREENSHOTS"].map { URL(filePath: $0) }

/// Draws a window's frame at 2× into a PNG. The frame is taken out of its window first, so the title bar is
/// drawn as the active window's. `overlays` are images (a web page's snapshot) drawn over parts of it.
@MainActor func saveScreenshot(of window: NSWindow, as name: String, language: String, overlays: [(NSImage, CGRect)] = []) throws {
    guard let screenshotFolder, let frame = window.contentView else { return }
    let folder = screenshotFolder.appending(path: language)
    try FileManager.default.createDirectory(at: folder.appending(path: "parts"), withIntermediateDirectories: true)
    // Still in its window, which isn't the key one: the title bar of a window in the background, for the desktop picture.
    try render(frame, overlays: overlays)?.write(to: folder.appending(path: "parts/\(name)-inactive.png"))
    window.contentView = nil
    try render(frame, overlays: overlays)?.write(to: folder.appending(path: "\(name).png"))
}

@MainActor private func render(_ frame: NSView, overlays: [(NSImage, CGRect)]) -> Data? {
    let size = frame.bounds.size
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: Int(size.width) * 2, pixelsHigh: Int(size.height) * 2, bitsPerSample: 8,
        samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    ) else { return nil }
    rep.size = size
    frame.cacheDisplay(in: frame.bounds, to: rep)
    if let context = NSGraphicsContext(bitmapImageRep: rep) {
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        // The bitmap's coordinates start at the bottom; the frame's may start at the top.
        for (image, rect) in overlays {
            image.draw(in: frame.isFlipped ? CGRect(x: rect.minX, y: size.height - rect.maxY, width: rect.width, height: rect.height) : rect)
        }
        NSGraphicsContext.restoreGraphicsState()
    }
    return rep.representation(using: .png, properties: [:])
}
