import AppKit
import Testing
@testable import Retro98UI

@Test func menuTitlesAreSpacedFromTheLeft() {
    let frames = RetroMenuBar.titleFrames(titles: ["Arquivo", "Editar"], height: 22)
    let first = CGFloat(PixelText.width(of: "Arquivo", font: .regular)) + 14
    #expect(frames[0] == CGRect(x: 2, y: 0, width: first, height: 22))
    #expect(frames[1].minX == frames[0].maxX)
}

@MainActor @Test func toolbarFramesIncludeSeparators() {
    let a = ToolbarItem(title: "Voltar", icon: Icons.folder, isEnabled: true) {}
    let b = ToolbarItem(title: "Ir", icon: Icons.folder, isEnabled: true) {}
    let frames = RetroToolbar.frames(items: [a, nil, b], height: 42)
    let aWidth = max(CGFloat(PixelText.width(of: "Voltar", font: .regular)) + 10, 48)
    #expect(frames[0] == CGRect(x: 4, y: 0, width: aWidth, height: 42))
    #expect(frames[1] == CGRect(x: 4 + aWidth, y: 0, width: 8, height: 42))
    #expect(frames[2].width == 48)                     // short title still gets the minimum
}

@MainActor @Test func disabledToolbarItemIsEmbossed() {
    let toolbar = RetroToolbar(frame: CGRect(x: 0, y: 0, width: 80, height: 42))
    toolbar.items = [ToolbarItem(title: "Colar", icon: Icons.document, isEnabled: false) {}]
    let image = renderView(toolbar)
    let pixels = allPixels(image)
    #expect(pixels.contains(Palette.shadow))
    #expect(pixels.contains(Palette.light))
    #expect(!pixels.contains(.black))
}

@Test func statusFieldsFillTheRest() {
    let frames = RetroStatusBar.fieldFrames(widths: [300, 140, nil], totalWidth: 680, height: 24)
    #expect(frames[0] == CGRect(x: 2, y: 2, width: 300, height: 20))
    #expect(frames[1].minX == CGFloat(2 + 300 + 4))
    #expect(frames[2].maxX == CGFloat(680 - 4 - 12))
}
