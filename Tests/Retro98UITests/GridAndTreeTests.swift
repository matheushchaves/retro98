import CoreGraphics
import Testing
@testable import Retro98UI

@Test func gridColumnsAndFrames() {
    #expect(IconGridLayout.columns(forWidth: 450) == 4)
    #expect(IconGridLayout.columns(forWidth: 10) == 1)
    #expect(IconGridLayout.frame(of: 5, columns: 4) == CGRect(x: CGFloat(8 + 88), y: CGFloat(8 + 76), width: 88, height: 76))
    #expect(IconGridLayout.contentHeight(count: 9, columns: 4) == CGFloat(8 + 3 * 76 + 8))
}

@Test func visibleIndicesOnlyCoverTheRect() {
    let range = IconGridLayout.indices(in: CGRect(x: 0, y: CGFloat(76 * 100), width: 450, height: 300), columns: 4, count: 10_000)
    #expect(range == 396..<416)
    #expect(IconGridLayout.indices(in: CGRect(x: 0, y: 0, width: 450, height: 300), columns: 4, count: 3) == 0..<3)
}

@Test func indexAtPoint() {
    let center = CGPoint(x: CGFloat(8 + 88 + 44), y: CGFloat(8 + 76 + 30))
    #expect(IconGridLayout.index(at: center, columns: 4, count: 10) == 5)
    #expect(IconGridLayout.index(at: CGPoint(x: 50, y: 5000), columns: 4, count: 10) == nil)
    #expect(IconGridLayout.index(at: CGPoint(x: 400, y: 30), columns: 4, count: 10) == nil)    // past the last column
}

@Test func labelWrapsToTwoLinesWithEllipsis() {
    // RetroText.label measures with PixelText; check the shape rather than exact glyph widths.
    let lines = RetroText.label("Captura de Tela 2026-11-11 às 14.32.10.png", maxWidth: 84, maxLines: 2)
    #expect(lines.count == 2)
    #expect(lines[1].hasSuffix("…"))
    #expect(lines.allSatisfy { PixelText.width(of: $0, font: .regular) <= 84 })
    #expect(RetroText.label("Lixeira", maxWidth: 84, maxLines: 2) == ["Lixeira"])
    let oneLongWord = RetroText.label("Supercalifragilisticexpialidocious", maxWidth: 84, maxLines: 2)
    #expect(oneLongWord.count == 1 && oneLongWord[0].hasSuffix("…"))
}

@Test func flattenRespectsExpansion() {
    let children = ["d": ["c", "m"], "c": ["hd"]]
    let rows = TreeRows.flatten(roots: ["d"], children: { children[$0] ?? [] }, expanded: ["d", "c"])
    #expect(rows == [TreeRow(id: "d", depth: 0), TreeRow(id: "c", depth: 1), TreeRow(id: "hd", depth: 2), TreeRow(id: "m", depth: 1)])
    #expect(TreeRows.flatten(roots: ["d"], children: { children[$0] ?? [] }, expanded: []) == [TreeRow(id: "d", depth: 0)])
}
