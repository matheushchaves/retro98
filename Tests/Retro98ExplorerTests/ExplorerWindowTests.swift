import AppKit
import Testing
@testable import Retro98Explorer
@testable import Retro98FilesCore
import Retro98UI

@MainActor private func environment(_ home: TempTree) -> ExplorerEnvironment {
    ExplorerEnvironment(home: home.root, languages: ["pt-BR"], showHidden: false,
                        volumes: { [VolumeInfo(url: URL(filePath: "/"), name: "Macintosh HD", kind: .internal,
                                               totalBytes: 1000, freeBytes: 500, isEjectable: false)] },
                        trash: home.root.appending(path: ".Trash"))
}

/// A download finishing (a file appearing) must not reset what the person is doing.
@MainActor @Test func backgroundReloadKeepsSelectionScrollAndAddressEdits() throws {
    let home = try TempTree((0..<60).map { "Desktop/f\($0).txt" } + [".Trash"])
    let controller = ExplorerWindowController(start: .desktop, languages: ["pt-BR"], environment: environment(home))
    let index = try #require(controller.model.entries.firstIndex { $0.name == "f50.txt" })
    controller.grid.setSelection([index])
    let clip = try #require(controller.grid.enclosingScrollView?.contentView)
    clip.scroll(to: CGPoint(x: 0, y: 300))
    controller.window.makeFirstResponder(controller.address.field)
    controller.address.field.currentEditor()?.string = "~/Down"

    try Data().write(to: home.root.appending(path: "Desktop/aaa.txt"))   // sorts first: every index shifts
    controller.model.reload()

    #expect(controller.grid.selection.map { controller.model.entries[$0].name } == ["f50.txt"])
    #expect(clip.bounds.origin.y == 300)
    #expect(controller.address.field.currentEditor()?.string == "~/Down")
}

@MainActor @Test func navigatingStillResetsTheView() throws {
    let home = try TempTree((0..<60).map { "Desktop/f\($0).txt" } + ["Desktop/Pasta/x.txt", ".Trash"])
    let controller = ExplorerWindowController(start: .desktop, languages: ["pt-BR"], environment: environment(home))
    controller.grid.setSelection([5])
    let folder = try #require(controller.model.entries.first { $0.name == "Pasta" })
    _ = controller.model.open(folder)
    #expect(controller.grid.selection.isEmpty)
    #expect(controller.address.field.stringValue == home.root.appending(path: "Desktop/Pasta").path)
}

/// Quick Look keeps asking for the old item count until it reloads; a stale index must not crash.
@MainActor @Test func quickLookIgnoresStaleIndexes() throws {
    let home = try TempTree(["Desktop/a.txt", ".Trash"])
    let controller = ExplorerWindowController(start: .desktop, languages: ["pt-BR"], environment: environment(home))
    let scroll = try #require(controller.grid.enclosingScrollView as? QuickLookScrollView)
    #expect(scroll.previewPanel(nil, previewItemAt: 5) == nil)
}

@MainActor @Test func menusKeepStandardMacShortcuts() {
    let items = ExplorerMenus.mainMenu(languages: ["pt-BR"]).items.flatMap { $0.submenu?.items ?? [] }
    func has(_ key: String, _ modifiers: NSEvent.ModifierFlags, _ action: String) -> Bool {
        items.contains { $0.keyEquivalent == key && $0.keyEquivalentModifierMask == modifiers && $0.action.map(NSStringFromSelector) == action }
    }
    #expect(has("h", .command, "hide:"))
    #expect(has("h", [.command, .option], "hideOtherApplications:"))
    #expect(has("m", .command, "miniaturize:"))
    #expect(has("z", .command, "undo:"))
    #expect(has("z", [.command, .shift], "redo:"))
    #expect(items.contains { $0.action.map(NSStringFromSelector) == "unhideAllApplications:" })
    #expect(items.contains { $0.action.map(NSStringFromSelector) == "zoom:" })
}

@MainActor @Test func treeShowsTheTrashStateFromTheLastRefresh() throws {
    let home = try TempTree([".Trash"])
    let tree = ExplorerTree(environment: environment(home), languages: ["pt-BR"])
    let empty = FileIcons.icon(.recycleBinEmpty, size: 16).image(), full = FileIcons.icon(.recycleBinFull, size: 16).image()
    let view = RetroTreeView()
    #expect(tree.tree(view, iconOf: ExplorerTree.trashID).image() === empty)
    try Data().write(to: home.root.appending(path: ".Trash/lixo.txt"))
    tree.refreshTrash()
    #expect(tree.tree(view, iconOf: ExplorerTree.trashID).image() === full)
}
