import AppKit
import Testing
@testable import Retro98UI

private let fontsFolder = URL(filePath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    .deletingLastPathComponent().appending(path: "Resources/Fonts")
private let vgaFontURL = fontsFolder.appending(path: "PxPlus_IBM_VGA_8x16.ttf")

private func advance(_ font: NSFont, _ character: Character) -> CGFloat {
    var units = Array(String(character).utf16)
    var glyphs = [CGGlyph](repeating: 0, count: units.count)
    CTFontGetGlyphsForCharacters(font, &units, &glyphs, units.count)
    var size = CGSize.zero
    CTFontGetAdvancesForGlyphs(font, .horizontal, &glyphs, &size, 1)
    return size.width
}

@MainActor @Test func vgaFontHasAnExactCell() {
    #expect(VGAFont.register(at: vgaFontURL))
    let font = VGAFont.make()
    #expect(font.fontName == VGAFont.postScriptName)
    #expect(advance(font, "W") == 8)
    #expect(CTFontGetAscent(font) + CTFontGetDescent(font) + CTFontGetLeading(font) == 16)
}

@MainActor @Test func vgaFontCoversPortuguese() {
    VGAFont.register(at: vgaFontURL)
    let font = VGAFont.make()
    let missing = "ãõçÃÕÇáéíóúâêôàüÁÉÍÓÚÂÊÔÀ€─│┌┐└┘█░▒▓→…“”".filter { character in
        var units = Array(String(character).utf16)
        var glyphs = [CGGlyph](repeating: 0, count: units.count)
        return !CTFontGetGlyphsForCharacters(font, &units, &glyphs, units.count)
    }
    #expect(missing.isEmpty)
}

@MainActor @Test func missingFontFileIsNotRegistered() {
    #expect(!VGAFont.register(at: fontsFolder.appending(path: "nao-existe.ttf")))
    #expect(VGAFont.make().pointSize == 16)
}
