import AppKit
import Testing
@testable import Retro98UI

private let heroFolder = ProcessInfo.processInfo.environment["RETRO98_SCREENSHOTS"].map { URL(filePath: $0) }

/// The README's opening picture: the app windows the other targets drew, laid over the teal desktop, with a
/// taskbar put together from the real Start button, task buttons and tray field. It is a composition, not a
/// capture of a screen. Run after the window screenshots (scripts/make-screenshots.sh does both).
@MainActor @Test(.enabled(if: heroFolder != nil), arguments: ["en", "pt-BR"])
func screenshotHero(language: String) throws {
    let folder = try #require(heroFolder).appending(path: language)
    let size = CGSize(width: 1360, height: 820), taskbarHeight: CGFloat = 28
    let rep = try #require(NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: Int(size.width) * 2, pixelsHigh: Int(size.height) * 2, bitsPerSample: 8,
        samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    ))
    rep.size = size
    let context = try #require(NSGraphicsContext(bitmapImageRep: rep))
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    defer { NSGraphicsContext.restoreGraphicsState() }
    context.imageInterpolation = .none

    /// Draws at a top-left position (the bitmap's own coordinates start at the bottom).
    func place(_ image: NSImage, x: CGFloat, top: CGFloat) {
        image.draw(in: CGRect(x: x, y: size.height - top - image.size.height, width: image.size.width, height: image.size.height))
    }
    func window(_ name: String) throws -> NSImage {
        let image = try #require(NSImage(contentsOf: folder.appending(path: name)), "\(name) is missing: run the window screenshots first")
        image.size = CGSize(width: image.size.width, height: image.size.height)
        if let pixels = image.representations.first { image.size = CGSize(width: pixels.pixelsWide / 2, height: pixels.pixelsHigh / 2) }
        return image
    }
    func picture(of view: NSView) throws -> NSImage {
        let viewRep = try #require(NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: Int(view.bounds.width) * 2, pixelsHigh: Int(view.bounds.height) * 2, bitsPerSample: 8,
            samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        ))
        viewRep.size = view.bounds.size
        view.cacheDisplay(in: view.bounds, to: viewRep)
        let image = NSImage(size: view.bounds.size)
        image.addRepresentation(viewRep)
        return image
    }

    NSColor(srgbRed: 0, green: 0x80 / 255.0, blue: 0x80 / 255.0, alpha: 1).setFill()
    CGRect(origin: .zero, size: size).fill()
    try place(window("parts/browser-inactive.png"), x: 428, top: 22)
    try place(window("parts/explorer-inactive.png"), x: 26, top: 128)
    try place(window("notepad.png"), x: 742, top: 398)

    // The taskbar: face with the raised top edge, Start, one button per window (the active one pressed), the clock.
    let isPortuguese = language.hasPrefix("pt")
    let barTop = size.height - taskbarHeight
    NSColor(srgbRed: 0xC0 / 255.0, green: 0xC0 / 255.0, blue: 0xC0 / 255.0, alpha: 1).setFill()
    CGRect(x: 0, y: 0, width: size.width, height: taskbarHeight).fill()
    NSColor.white.setFill()
    CGRect(x: 0, y: taskbarHeight - 2, width: size.width, height: 1).fill()
    let start = RetroButton(title: isPortuguese ? "Iniciar" : "Start", icon: Icons.startLogo, bold: true) {}
    start.frame = CGRect(x: 0, y: 0, width: start.frame.width, height: 22)
    try place(picture(of: start), x: 2, top: barTop + 4)
    let tasks: [(String, PixelIcon, Bool)] = [
        (isPortuguese ? "Página inicial - Navegador" : "Home - Browser", BrowserIcons.appSmall, false),
        (isPortuguese ? "Área de Trabalho" : "Desktop", FileIcons.explorerAppSmall, false),
        (isPortuguese ? "leia-me.txt - Bloco de Notas" : "readme.txt - Notepad", FileIcons.notepadAppSmall, true),
    ]
    var x = start.frame.width + 10
    for task in tasks {
        let button = RetroButton(title: RetroText.fit(task.0, maxWidth: 120), icon: task.1, bold: task.2) {}
        button.frame = CGRect(x: 0, y: 0, width: 160, height: 22)
        button.isPressed = task.2
        try place(picture(of: button), x: x, top: barTop + 4)
        x += 163
    }
    let tray = PixelCanvas.render(width: 64, height: 22) { context in
        Bevel.fillFace(CGRect(x: 0, y: 0, width: 64, height: 22), context: context)
        Bevel.draw(.statusField, in: CGRect(x: 0, y: 0, width: 64, height: 22), context: context)
        PixelText.draw("14:05", font: .regular, color: .black, at: CGPoint(x: 16, y: 3), context: context)
    }
    let trayImage = NSImage(cgImage: tray.cgImage, size: CGSize(width: 64, height: 22))
    place(trayImage, x: size.width - 66, top: barTop + 4)

    try rep.representation(using: .png, properties: [:])?.write(to: folder.appending(path: "desktop.png"))
}
