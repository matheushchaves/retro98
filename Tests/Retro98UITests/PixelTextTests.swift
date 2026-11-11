import CoreGraphics
import Testing
@testable import Retro98UI

@Test func textRendersOnlyPureColors() {
    let image = PixelCanvas.render(width: 80, height: PixelText.lineHeight) { context in
        Bevel.fillFace(CGRect(x: 0, y: 0, width: 80, height: PixelText.lineHeight), context: context)
        PixelText.draw("Iniciar", font: .bold, color: .black, at: .zero, context: context)
    }
    #expect(allPixels(image).allSatisfy { $0 == Palette.face || $0 == .black })
    #expect(allPixels(image).contains(.black))
}

@Test func textIsUprightInTopLeftCanvas() {
    // "T": the crossbar (top) must have more ink than the bottom rows.
    let image = PixelCanvas.render(width: 12, height: PixelText.lineHeight) { context in
        Bevel.fill(CGRect(x: 0, y: 0, width: 12, height: PixelText.lineHeight), color: .white, context: context)
        PixelText.draw("T", font: .regular, color: .black, at: .zero, context: context)
    }
    let ink = { (y: Int) in (0..<12).filter { image.color(x: $0, y: y) == .black }.count }
    let rows = (0..<PixelText.lineHeight).map(ink)
    let firstInkRow = rows.firstIndex { $0 > 0 }!
    #expect(rows[firstInkRow] > rows[firstInkRow + 4])
}

@Test func boldIsWiderThanRegular() {
    #expect(PixelText.width(of: "Iniciar", font: .bold) > PixelText.width(of: "Iniciar", font: .regular))
    #expect(PixelText.width(of: "", font: .regular) == 0)
}
