import AppKit
import Testing
@testable import Retro98UI

private func draw(_ size: CGSize, _ body: (CGContext) -> Void) -> PixelImage {
    PixelCanvas.render(width: Int(size.width), height: Int(size.height), body)
}

@Test func arrowButtonIsRaisedWithBlackTriangle() {
    let image = draw(CGSize(width: 16, height: 16)) { RetroScroller.drawArrowButton(.up, pressed: false, in: CGRect(x: 0, y: 0, width: 16, height: 16), context: $0) }
    #expect(image.color(x: 0, y: 0) == Palette.face)       // window-style bevel: face, then light
    #expect(image.color(x: 1, y: 1) == Palette.light)
    #expect(image.color(x: 7, y: 7) == .black)
}

@Test func pressedArrowIsSunken() {
    let image = draw(CGSize(width: 16, height: 16)) { RetroScroller.drawArrowButton(.down, pressed: true, in: CGRect(x: 0, y: 0, width: 16, height: 16), context: $0) }
    #expect(image.color(x: 0, y: 0) == Palette.shadow)
}

@Test func trackIsCheckered() {
    let image = draw(CGSize(width: 16, height: 40)) { RetroScroller.drawTrack(in: CGRect(x: 0, y: 0, width: 16, height: 40), context: $0) }
    #expect(image.color(x: 0, y: 0) == .white)
    #expect(image.color(x: 1, y: 0) == Palette.face)
    #expect(image.color(x: 1, y: 1) == .white)
}

@Test func knobUsesWindowBevel() {
    let image = draw(CGSize(width: 16, height: 40)) { RetroScroller.drawKnob(in: CGRect(x: 0, y: 0, width: 16, height: 40), context: $0) }
    #expect(image.color(x: 0, y: 0) == Palette.face)
    #expect(image.color(x: 1, y: 1) == Palette.light)
    #expect(image.color(x: 15, y: 39) == .black)
}

@Test func knobRectFollowsValueAndProportion() {
    // Vertical scroller 16×200: arrows take 16 at each end, so the slot is 168 tall.
    let rect = RetroScroller.knobRect(length: 200, thickness: 16, value: 0.5, proportion: 0.25, vertical: true)
    #expect(rect.height == 42)                                    // 168 × 0.25
    #expect(rect.minY == 16 + (168 - 42) * 0.5)
    #expect(RetroScroller.knobRect(length: 200, thickness: 16, value: 0, proportion: 0.01, vertical: true).height == 8)  // minimum knob
}

@MainActor @Test func scrollViewUsesRetroScrollers() {
    let scroll = RetroScroller.makeScrollView(document: NSView(frame: CGRect(x: 0, y: 0, width: 100, height: 1000)))
    #expect(scroll.verticalScroller is RetroScroller)
    #expect(scroll.horizontalScroller is RetroScroller)
    #expect(scroll.scrollerStyle == .legacy)
    #expect(scroll.autohidesScrollers)   // like 98 list views: bars only when there is something to scroll
}
