import Testing
@testable import Retro98UI

@Test func controlPanelIconsAreOriginalPixelArt() {
    #expect(ControlPanelIcons.app.width == 32 && ControlPanelIcons.app.height == 32 && opaqueRatio(ControlPanelIcons.app) > 1.0 / 8.0)
    #expect(ControlPanelIcons.appSmall.width == 16 && ControlPanelIcons.appSmall.height == 16
        && opaqueRatio(ControlPanelIcons.appSmall) > 1.0 / 8.0)
    for kind in ControlPanelIcon.allCases {
        for size in [16, 32] {
            let icon = ControlPanelIcons.icon(kind, size: size)
            #expect(icon.width == size && icon.height == size, "\(kind) \(size)")
            #expect(opaqueRatio(icon) > 1.0 / 8.0, "\(kind) \(size) looks empty")
        }
    }
    let renders = ControlPanelIcon.allCases.map { allPixels(render(ControlPanelIcons.icon($0, size: 32))) }
    for (i, a) in renders.enumerated() {
        for b in renders.dropFirst(i + 1) { #expect(a != b) }
    }
    #expect(ControlPanelIcon.allCases.count == 11)
}
