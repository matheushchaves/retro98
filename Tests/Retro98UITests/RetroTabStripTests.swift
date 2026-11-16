import AppKit
import Testing
@testable import Retro98UI

@Test func tabsShareTheWidth() {
    let layout = RetroTabStrip.layout(count: 3, selected: 0, width: 800)
    #expect(layout.tabs.map(\.minX) == [2, 162, 322])
    #expect(layout.tabs.allSatisfy { $0.width == 160 })
    #expect(layout.newButton.minX == layout.tabs[2].maxX + 2)
    #expect(layout.newButton.width == RetroTabStrip.newButtonWidth)
}

@Test func tabsShrinkToFit() {
    let layout = RetroTabStrip.layout(count: 10, selected: 0, width: 800)
    #expect(layout.tabs.allSatisfy { $0.width == 77 })
    #expect(layout.newButton.maxX <= 800)
}

@Test func tabsNeverGoBelowTheMinimum() {
    #expect(RetroTabStrip.layout(count: 30, selected: 0, width: 800).tabs.allSatisfy { $0.width == 60 })
}

@Test func selectedTabIsAlwaysVisible() {
    // The tabs' area runs from x 2 to 2 pt before the new-tab button, which ends at the right edge.
    let areaEnd: CGFloat = 800 - 24
    let last = RetroTabStrip.layout(count: 30, selected: 29, width: 800)
    #expect(last.tabs[29].minX >= 2 && last.tabs[29].maxX <= areaEnd)
    #expect(last.newButton.minX == areaEnd + 2 && last.newButton.maxX == 800)
    let first = RetroTabStrip.layout(count: 30, selected: 0, width: 800)
    #expect(first.tabs[0].minX == 2)
    let middle = RetroTabStrip.layout(count: 30, selected: 15, width: 800)
    #expect(middle.tabs[15].minX >= 2 && middle.tabs[15].maxX <= areaEnd)
}

@Test func closeBoxSitsInsideItsTab() {
    let layout = RetroTabStrip.layout(count: 12, selected: 3, width: 800)
    #expect(layout.closeBoxes.count == 12)
    for (tab, box) in zip(layout.tabs, layout.closeBoxes) {
        #expect(box.size == CGSize(width: 14, height: 14))
        #expect(tab.contains(box))
    }
}

@Test func noTabsStillHasTheNewButton() {
    let layout = RetroTabStrip.layout(count: 0, selected: 0, width: 800)
    #expect(layout.tabs.isEmpty)
    #expect(layout.newButton.minX == 2)
}

@Test func labelIsOneLine() {
    #expect(RetroTabStrip.label("a\nb\tc", tabWidth: 160) == "a b c")
    let long = RetroTabStrip.label(String(repeating: "m", count: 10_000), tabWidth: 160)
    #expect(long.hasSuffix("…"))
    #expect(PixelText.width(of: long, font: .regular) <= 130)
    #expect(RetroTabStrip.label("", tabWidth: 160) == "")
    #expect(RetroTabStrip.label("<b>oi</b>", tabWidth: 160) == "<b>oi</b>")
}

@MainActor @Test func clicksReachTheRightCallback() {
    let strip = RetroTabStrip(frame: CGRect(x: 0, y: 0, width: 800, height: RetroTabStrip.height))
    strip.titles = ["um", "dois", "três"]
    var selected: [Int] = [], closed: [Int] = [], new = 0
    strip.onSelect = { selected.append($0) }
    strip.onClose = { closed.append($0) }
    strip.onNew = { new += 1 }
    let layout = RetroTabStrip.layout(count: 3, selected: 0, width: 800)
    func middle(_ rect: CGRect) -> CGPoint { CGPoint(x: rect.midX, y: rect.midY) }

    strip.press(at: CGPoint(x: layout.tabs[1].minX + 10, y: 12))
    strip.release(at: CGPoint(x: layout.tabs[1].minX + 10, y: 12))
    #expect(selected == [1] && closed.isEmpty)

    strip.press(at: middle(layout.closeBoxes[1]))
    strip.release(at: middle(layout.closeBoxes[1]))
    #expect(selected == [1] && closed == [1])

    // Letting go outside the close box closes nothing.
    strip.press(at: middle(layout.closeBoxes[2]))
    strip.release(at: CGPoint(x: 700, y: 12))
    #expect(closed == [1])

    strip.press(at: middle(layout.newButton))
    strip.release(at: middle(layout.newButton))
    #expect(new == 1)

    strip.middleClick(at: middle(layout.tabs[2]))
    #expect(closed == [1, 2])
    strip.middleClick(at: CGPoint(x: 700, y: 12))
    #expect(closed == [1, 2])
}

@MainActor @Test func tabStripDrawsEveryTitleInPlainColors() {
    let strip = RetroTabStrip(frame: CGRect(x: 0, y: 0, width: 400, height: RetroTabStrip.height))
    strip.titles = ["Exemplo", "Outra"]
    strip.selected = 1
    let colors = Set(allPixels(renderView(strip)))
    #expect(colors.isSubset(of: [Palette.face, Palette.shadow, Palette.light, Palette.darkShadow]))
    #expect(colors.contains(Palette.darkShadow))
}
