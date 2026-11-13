import AppKit
import Retro98UI
import SwiftTerm
import Testing
@testable import Retro98Prompt

/// A plain SwiftTerm view in the VGA font: black, light gray text, no smoothing, the font's own block glyphs.
@MainActor private func vgaTerminal() -> TerminalView {
    VGAFont.register(at: vgaFontURL)
    let view = TerminalView(frame: CGRect(x: 0, y: 0, width: 640, height: 400), font: VGAFont.make())
    view.nativeBackgroundColor = .black
    view.nativeForegroundColor = NSColor(srgbRed: 0xC0 / 255, green: 0xC0 / 255, blue: 0xC0 / 255, alpha: 1)
    view.fontSmoothing = false
    view.customBlockGlyphs = false
    view.subviews.compactMap { $0 as? NSScroller }.forEach { $0.isHidden = true }
    view.setFrameSize(CGSize(width: 641, height: 400))
    view.setFrameSize(CGSize(width: 640, height: 400))
    return view
}

@MainActor @Test func vendoredTerminalDrawsCrispPixels() {
    let view = vgaTerminal()
    view.feed(text: "C:\\> Olá, ação: ãõç ┌──┐ █▓▒░\r\n")
    #expect(distinctColors(view, rows: 1) == 2)
}

@MainActor @Test func hiddenScrollerLeavesEightyColumns() {
    let view = vgaTerminal()
    #expect(view.getTerminal().cols == 80)
    #expect(view.getTerminal().rows == 25)
}
