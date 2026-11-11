import CoreGraphics
import Testing
@testable import Retro98UI

@Test func regionRenderUsesViewCoordinates() {
    let image = PixelCanvas.render(region: CGRect(x: 10, y: 20, width: 5, height: 5)) { context in
        Bevel.fill(CGRect(x: 0, y: 0, width: 100, height: 100), color: Palette.face, context: context)
        Bevel.fill(CGRect(x: 12, y: 22, width: 1, height: 1), color: .black, context: context)
    }
    #expect(image.width == 5 && image.height == 5)
    #expect(image.color(x: 2, y: 2) == .black)
    #expect(image.color(x: 0, y: 0) == Palette.face)
}

@Test func regionRenderClipsToTheRegion() {
    var clip = CGRect.zero
    _ = PixelCanvas.render(region: CGRect(x: 10, y: 20, width: 5, height: 5)) { clip = $0.boundingBoxOfClipPath }
    #expect(clip == CGRect(x: 10, y: 20, width: 5, height: 5))
}

@Test func fullRenderStillWorks() {
    let image = PixelCanvas.render(width: 3, height: 2) { Bevel.fill(CGRect(x: 2, y: 1, width: 1, height: 1), color: .black, context: $0) }
    #expect(image.color(x: 2, y: 1) == .black)
}

@MainActor private final class CornerView: PixelView {
    override func drawPixels(in context: CGContext, size: CGSize) {
        Bevel.fill(CGRect(origin: .zero, size: size), color: .white, context: context)
        Bevel.fill(CGRect(x: 0, y: 0, width: 2, height: 2), color: .black, context: context)          // top-left
        Bevel.fill(CGRect(x: size.width - 2, y: size.height - 2, width: 2, height: 2), color: Palette.selection, context: context)
    }
}

@MainActor @Test func pixelViewDrawsUprightThroughAppKit() throws {
    let view = CornerView(frame: CGRect(x: 0, y: 0, width: 20, height: 10))
    let rep = try #require(view.bitmapImageRepForCachingDisplay(in: view.bounds))
    view.cacheDisplay(in: view.bounds, to: rep)
    let scale = CGFloat(rep.pixelsWide) / view.bounds.width
    let topLeft = try #require(rep.colorAt(x: 0, y: 0)?.usingColorSpace(.sRGB))
    let bottomRight = try #require(rep.colorAt(x: rep.pixelsWide - 1, y: rep.pixelsHigh - 1)?.usingColorSpace(.sRGB))
    #expect(scale >= 1)
    #expect(topLeft.redComponent < 0.1 && topLeft.blueComponent < 0.1)
    #expect(bottomRight.blueComponent > 0.4 && bottomRight.redComponent < 0.1)
}
