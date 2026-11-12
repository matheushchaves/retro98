import AppKit
import Testing
@testable import Retro98Explorer
@testable import Retro98FilesCore
import Retro98UI

private let pt = ["pt-BR"]

@MainActor private func window(_ ops: OperationsHarness, at path: String) -> ExplorerWindowController {
    ExplorerWindowController(start: .folder(ops.url(path)), languages: pt, environment: ops.operations.environment, operations: ops.operations)
}

private func write(_ url: URL, bytes: Int) throws {
    try Data(repeating: 65, count: bytes).write(to: url)
}

@MainActor @Test func viewCommandsSwitchModesAndRemember() throws {
    let ops = try OperationsHarness(["A/a.txt"])
    let controller = window(ops, at: "A")
    controller.showDetails(nil)
    #expect(controller.grid.style == .details)
    #expect(ops.operations.environment.preferences.viewMode == .details)
    #expect(!controller.gridPane.header.isHidden)
    #expect(window(ops, at: "A").grid.style == .details)
    controller.showList(nil)
    #expect(controller.grid.style == .list)
    #expect(controller.grid.enclosingScrollView?.hasHorizontalScroller == true)
    #expect(controller.gridPane.header.isHidden)
    controller.showLargeIcons(nil)
    #expect(controller.grid.enclosingScrollView?.hasHorizontalScroller == false)
}

@MainActor @Test func headerSortsAndReverses() throws {
    let ops = try OperationsHarness(["A"])
    try write(ops.url("A/grande.txt"), bytes: 30)
    try write(ops.url("A/pequeno.txt"), bytes: 10)
    let controller = window(ops, at: "A")
    controller.showDetails(nil)
    let header = controller.gridPane.header
    header.onClick?(1)
    #expect(controller.model.sort == SortOrder(key: .size, ascending: true))
    #expect(controller.model.entries.map(\.name) == ["pequeno.txt", "grande.txt"])
    #expect(header.sortedColumn == 1 && header.ascending)
    header.onClick?(1)
    #expect(controller.model.sort == SortOrder(key: .size, ascending: false))
    #expect(controller.model.entries.map(\.name) == ["grande.txt", "pequeno.txt"])
    #expect(!header.ascending)
    #expect(controller.grid(controller.grid, detailsAt: 0).first == "30 bytes")
}

@MainActor @Test func hiddenFilesToggleAndLookGhosted() throws {
    let ops = try OperationsHarness(["A/.oculto.txt", "A/normal.txt"])
    let controller = window(ops, at: "A")
    #expect(!controller.model.entries.contains { $0.name == ".oculto.txt" })
    controller.toggleHiddenFiles(nil)
    let index = try #require(controller.model.entries.firstIndex { $0.name == ".oculto.txt" })
    let normal = try #require(controller.model.entries.firstIndex { $0.name == "normal.txt" })
    #expect(controller.grid(controller.grid, isDimmedAt: index))
    #expect(!controller.grid(controller.grid, isDimmedAt: normal))
}

@MainActor @Test func otherWindowsFollow() throws {
    let ops = try OperationsHarness(["A/.oculto.txt", "A/normal.txt"])
    let first = window(ops, at: "A"), second = window(ops, at: "A")
    first.toggleHiddenFiles(nil)
    #expect(second.model.entries.contains { $0.name == ".oculto.txt" })
    first.showSmallIcons(nil)
    #expect(second.grid.style == .smallIcons)
}

@MainActor @Test func viewMenuShowsMarks() throws {
    let ops = try OperationsHarness(["A/a.txt"])
    let controller = window(ops, at: "A")
    controller.showDetails(nil)
    controller.toggleHiddenFiles(nil)
    let view = ExplorerMenus.groups(pt)[2].commands.compactMap { $0 }
    func mark(_ action: String) -> RetroMenuItem.Mark? {
        view.first { NSStringFromSelector($0.selector) == action }.map { ExplorerMenus.validated($0, target: controller).mark }
    }
    #expect(mark("showDetails:") == .bullet)
    #expect(mark("showList:") == RetroMenuItem.Mark.none)
    #expect(mark("arrangeByName:") == .bullet)
    #expect(mark("toggleHiddenFiles:") == .check)
}

@MainActor @Test func menusHaveTheViewShortcuts() {
    let items = ExplorerMenus.mainMenu(languages: pt).items.flatMap { $0.submenu?.items ?? [] }
    func has(_ key: String, _ modifiers: NSEvent.ModifierFlags, _ action: String) -> Bool {
        items.contains { $0.keyEquivalent == key && $0.keyEquivalentModifierMask == modifiers && $0.action.map(NSStringFromSelector) == action }
    }
    #expect(has("1", .command, "showLargeIcons:"))
    #expect(has("2", .command, "showSmallIcons:"))
    #expect(has("3", .command, "showList:"))
    #expect(has("4", .command, "showDetails:"))
    #expect(has(".", [.command, .shift], "toggleHiddenFiles:"))
}
