import AppKit
import SwiftTerm
import Testing
@testable import Retro98Prompt

@MainActor private func styledTerminal() -> TerminalView {
    PromptFont.register(at: vgaFontURL)
    let view = TerminalView(frame: CGRect(x: 0, y: 0, width: 640, height: 400))
    PromptStyle.apply(to: view)
    return view
}

@Test func paletteIsTheClassicConsole() {
    #expect(PromptStyle.ansiHex == [
        "000000", "800000", "008000", "808000", "000080", "800080", "008080", "C0C0C0",
        "808080", "FF0000", "00FF00", "FFFF00", "0000FF", "FF00FF", "00FFFF", "FFFFFF",
    ])
    let palette = PromptStyle.palette
    #expect(palette.count == 16)
    #expect(palette[7].red == 0xC0C0)
    #expect(palette[12].red == 0 && palette[12].green == 0 && palette[12].blue == 0xFFFF)
}

@MainActor @Test func applyConfiguresTheTerminal() {
    let view = styledTerminal()
    #expect(!view.optionAsMetaKey)
    #expect(!view.fontSmoothing)
    #expect(!view.customBlockGlyphs)
    #expect(view.getTerminal().options.scrollback == 10_000)
    #expect(view.getTerminal().options.cursorStyle == .blinkUnderline)
    #expect(view.getTerminal().cols == 80)
    #expect(view.getTerminal().rows == 25)
    #expect(!view.subviews.contains { $0 is NSScroller && !$0.isHidden })
}

@MainActor @Test func historyKeepsTenThousandLines() throws {
    let view = styledTerminal()
    view.feed(text: (1...20_000).map(String.init).joined(separator: "\r\n") + "\r\n")
    let text = try #require(String(data: view.getTerminal().getBufferAsData(), encoding: .utf8))
    // Every buffer line ends in "\n", so the split's last piece is empty.
    let lines = text.split(separator: "\n", omittingEmptySubsequences: false).dropLast()
    #expect(lines.count <= 10_000 + 25)
    let first = try #require(lines.first.flatMap { Int($0.trimmingCharacters(in: .whitespaces)) })
    #expect(first >= 9_976)
}

@MainActor @Test func colorsStayCrisp() {
    let view = styledTerminal()
    view.feed(text: "\u{1b}[1;33mamarelo\u{1b}[0m \u{1b}[34mazul\u{1b}[0m ação\r\n")
    #expect(distinctColors(view, rows: 1) == 4)
}
