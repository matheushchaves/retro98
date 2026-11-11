import AppKit
import Testing
@testable import Retro98UI

@MainActor @Test func aboveDockPanelSitsOverTheDock() {
    let panel = AboveDockPanel()
    #expect(panel.level.rawValue == Int(CGWindowLevelForKey(.dockWindow)) + 1)
    #expect(panel.collectionBehavior.contains(.canJoinAllSpaces))
    #expect(!panel.hidesOnDeactivate)
    #expect(!panel.canBecomeKey)
}

@MainActor @Test func dialogsStayVisibleWhenAnotherAppIsClicked() {
    #expect(!RetroWindow(title: "Executar", contentSize: CGSize(width: 100, height: 50)).hidesOnDeactivate)
}

@Test func submenuOpensRightWhenItFits() {
    let x = RetroMenuPlacement.submenuX(parentFrame: CGRect(x: 0, y: 0, width: 200, height: 300), itemMaxX: 197,
                                        width: 150, visibleFrame: CGRect(x: 0, y: 0, width: 1440, height: 900))
    #expect(x == 198)
}

@Test func submenuFlipsLeftWhenRightIsTooNarrow() {
    let x = RetroMenuPlacement.submenuX(parentFrame: CGRect(x: 1200, y: 0, width: 200, height: 300), itemMaxX: 1397,
                                        width: 150, visibleFrame: CGRect(x: 0, y: 0, width: 1440, height: 900))
    #expect(x == 1050)
}

@Test func submenuNeverLeavesTheScreen() {
    // Parent at the far left and a submenu wider than the room on either side: clamp inside the screen.
    let visible = CGRect(x: 0, y: 0, width: 1440, height: 900)
    let x = RetroMenuPlacement.submenuX(parentFrame: CGRect(x: 2, y: 0, width: 300, height: 300), itemMaxX: 299,
                                        width: 1200, visibleFrame: visible)
    #expect(x >= visible.minX)
    #expect(x + 1200 <= visible.maxX)
}

@MainActor @Test func mainMenuProvidesStandardEditShortcuts() {
    let menu = StandardMenus.mainMenu(appName: "Retro98 Shell", languages: ["pt-BR"])
    let items = menu.items.flatMap { $0.submenu?.items ?? [] }
    let shortcuts = Dictionary(items.compactMap { item in item.action.map { (NSStringFromSelector($0), item.keyEquivalent) } },
                               uniquingKeysWith: { first, _ in first })
    #expect(shortcuts["cut:"] == "x")
    #expect(shortcuts["copy:"] == "c")
    #expect(shortcuts["paste:"] == "v")
    #expect(shortcuts["selectAll:"] == "a")
    #expect(shortcuts["undo:"] == "z")
}
