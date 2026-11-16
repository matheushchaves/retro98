import Testing
@testable import Retro98UI

@Test func browserIconsHaveTheRightSizes() {
    #expect(BrowserIcons.app.width == 32 && BrowserIcons.app.height == 32 && opaqueRatio(BrowserIcons.app) > 1.0 / 8.0)
    #expect(BrowserIcons.appSmall.width == 16 && BrowserIcons.appSmall.height == 16)
    let toolbar = [BrowserIcons.stop, BrowserIcons.refresh, BrowserIcons.home, BrowserIcons.favorites, BrowserIcons.history,
                   BrowserIcons.page]
    for icon in toolbar {
        #expect(icon.width == 16 && icon.height == 16)
        #expect(opaqueRatio(icon) > 1.0 / 8.0)
    }
    let renders = (toolbar + [BrowserIcons.appSmall]).map { allPixels(render($0)) }
    for (i, a) in renders.enumerated() {
        for b in renders.dropFirst(i + 1) { #expect(a != b) }
    }
}
