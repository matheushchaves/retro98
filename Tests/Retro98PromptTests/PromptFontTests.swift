import AppKit
import SwiftTerm
import Testing
@testable import Retro98Prompt

private func advance(_ font: NSFont, _ character: Character) -> CGFloat {
    var units = Array(String(character).utf16)
    var glyphs = [CGGlyph](repeating: 0, count: units.count)
    CTFontGetGlyphsForCharacters(font, &units, &glyphs, units.count)
    var size = CGSize.zero
    CTFontGetAdvancesForGlyphs(font, .horizontal, &glyphs, &size, 1)
    return size.width
}

/// A plain SwiftTerm view in the VGA font: black, light gray text, no smoothing, the font's own block glyphs.
@MainActor private func vgaTerminal() -> TerminalView {
    PromptFont.register(at: vgaFontURL)
    let view = TerminalView(frame: CGRect(x: 0, y: 0, width: 640, height: 400), font: PromptFont.make())
    view.nativeBackgroundColor = .black
    view.nativeForegroundColor = NSColor(srgbRed: 0xC0 / 255, green: 0xC0 / 255, blue: 0xC0 / 255, alpha: 1)
    view.fontSmoothing = false
    view.customBlockGlyphs = false
    view.subviews.compactMap { $0 as? NSScroller }.forEach { $0.isHidden = true }
    view.setFrameSize(CGSize(width: 641, height: 400))
    view.setFrameSize(CGSize(width: 640, height: 400))
    return view
}

@MainActor @Test func vgaFontHasAnExactCell() {
    #expect(PromptFont.register(at: vgaFontURL))
    let font = PromptFont.make()
    #expect(font.fontName == PromptFont.postScriptName)
    #expect(advance(font, "W") == 8)
    #expect(CTFontGetAscent(font) + CTFontGetDescent(font) + CTFontGetLeading(font) == 16)
}

@MainActor @Test func vgaFontCoversPortuguese() {
    PromptFont.register(at: vgaFontURL)
    let font = PromptFont.make()
    let missing = "ãõçÃÕÇáéíóúâêôàüÁÉÍÓÚÂÊÔÀ€─│┌┐└┘█░▒▓→…“”".filter { character in
        var units = Array(String(character).utf16)
        var glyphs = [CGGlyph](repeating: 0, count: units.count)
        return !CTFontGetGlyphsForCharacters(font, &units, &glyphs, units.count)
    }
    #expect(missing.isEmpty)
}

@MainActor @Test func missingFontFallsBackToSystemMonospace() {
    #expect(!PromptFont.register(at: repoRoot.appending(path: "Resources/Prompt/nao-existe.ttf")))
    let font = PromptFont.make()
    #expect(font.pointSize == 16)
    #expect(advance(font, "i") == advance(font, "W"))
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
