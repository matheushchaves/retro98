import AppKit
import Testing
@testable import Retro98Explorer
@testable import Retro98FilesCore
import Retro98UI

private let pt = ["pt-BR"]

/// A window on a temp tree, wired to test operations (private pasteboard, scripted prompts).
@MainActor private final class WindowHarness {
    let ops: OperationsHarness
    let controller: ExplorerWindowController

    init(_ paths: [String], at path: String? = nil, start: Location? = nil) throws {
        let ops = try OperationsHarness(paths)
        let location = start ?? path.map { .folder(ops.url($0)) } ?? .desktop
        self.ops = ops
        controller = ExplorerWindowController(start: location, languages: pt, environment: ops.operations.environment,
                                              operations: ops.operations)
    }

    func index(of name: String) -> Int? { controller.model.entries.firstIndex { $0.name == name } }
    func select(_ names: String...) { controller.grid.setSelection(IndexSet(names.compactMap(index(of:)))) }
    var selectedNames: [String] { controller.grid.selection.map { controller.model.entries[$0].name } }

    func enabled(_ action: Selector) -> Bool {
        controller.validateMenuItem(NSMenuItem(title: "", action: action, keyEquivalent: ""))
    }

    func settle() async { await controller.lastTask?.value }
}

// MARK: Command state

@MainActor @Test func fileCommandsFollowTheSelection() throws {
    let h = try WindowHarness(["Desktop/a.txt"])
    let commands = [#selector(ExplorerWindowController.copy(_:)), #selector(ExplorerWindowController.moveToTrash(_:))]
    #expect(commands.allSatisfy { !h.enabled($0) })
    h.select("a.txt")
    #expect(commands.allSatisfy { h.enabled($0) })
    h.select("Meu Computador", "a.txt")
    #expect(commands.allSatisfy { !h.enabled($0) })
}

@MainActor @Test func fileCommandsIgnoreTextEditing() throws {
    let h = try WindowHarness(["A/a.txt"], at: "A")
    h.select("a.txt")
    h.controller.window.makeFirstResponder(h.controller.address.field)
    #expect(h.controller.window.firstResponder is NSText)
    #expect(!h.enabled(#selector(ExplorerWindowController.moveToTrash(_:))))
    #expect(!h.enabled(#selector(ExplorerWindowController.copy(_:))))
    h.ops.prompter.answers = [0]
    h.controller.moveToTrash(nil)
    #expect(h.controller.lastTask == nil)
    #expect(h.ops.prompter.asked.isEmpty)
    #expect(h.ops.exists("A/a.txt"))
}

@MainActor @Test func retroEditMenuShowsTheUndoTitle() async throws {
    let h = try WindowHarness(["A/a.txt", "B"], at: "B")
    h.ops.operations.copy([h.ops.url("A/a.txt")])
    h.controller.paste(nil)
    await h.settle()
    let undo = try #require(ExplorerMenus.groups(pt)[1].commands.first ?? nil)
    let state = ExplorerMenus.validated(undo, target: h.controller.window)
    #expect(state.title == "Desfazer Copiar")
    #expect(state.isEnabled)
}

@MainActor @Test func menusHaveTheFileShortcuts() {
    let items = ExplorerMenus.mainMenu(languages: pt).items.flatMap { $0.submenu?.items ?? [] }
    func has(_ key: String, _ modifiers: NSEvent.ModifierFlags, _ action: String) -> Bool {
        items.contains { $0.keyEquivalent == key && $0.keyEquivalentModifierMask == modifiers && $0.action.map(NSStringFromSelector) == action }
    }
    #expect(has("o", .command, "openSelection:"))
    #expect(has("n", [.command, .shift], "newFolder:"))
    #expect(has("\u{8}", .command, "moveToTrash:"))
    #expect(has("\u{8}", [.command, .option], "deletePermanently:"))
    #expect(has("\u{8}", [.command, .shift], "emptyTrash:"))
    #expect(has("v", [.command, .option], "moveItemHere:"))
    #expect(items.contains { $0.action.map(NSStringFromSelector) == "renameSelection:" && $0.keyEquivalent.isEmpty })
}

// MARK: Flows

@MainActor @Test func newFolderStartsRenaming() async throws {
    let h = try WindowHarness(["A/a.txt"], at: "A")
    h.controller.newFolder(nil)
    await h.settle()
    #expect(h.selectedNames == ["Nova pasta"])
    #expect(h.controller.grid.editingIndex == h.index(of: "Nova pasta"))
    #expect(h.controller.grid.editor?.stringValue == "Nova pasta")
    #expect((h.controller.grid.editor?.currentEditor() as? NSTextView)?.selectedRange() == NSRange(location: 0, length: 10))
}

@MainActor @Test func renamingCommitsThroughTheGrid() async throws {
    let h = try WindowHarness(["A/foto.txt"], at: "A")
    h.select("foto.txt")
    h.controller.renameSelection(nil)
    let editor = try #require(h.controller.grid.editor)
    #expect((editor.currentEditor() as? NSTextView)?.selectedRange() == NSRange(location: 0, length: 4))
    editor.stringValue = "praia.txt"
    h.controller.grid.endEditing(commit: true)
    await h.settle()
    #expect(h.ops.exists("A/praia.txt") && !h.ops.exists("A/foto.txt"))
    #expect(h.selectedNames == ["praia.txt"])
}

@MainActor @Test func renameSurvivesABackgroundReload() throws {
    let h = try WindowHarness(["A/b.txt"], at: "A")
    h.select("b.txt")
    h.controller.renameSelection(nil)
    h.controller.grid.editor?.stringValue = "novo nome"
    try Data().write(to: h.ops.url("A/a.txt"))   // sorts first: b.txt moves to index 1
    h.controller.model.reload()
    #expect(h.controller.grid.editingIndex == h.index(of: "b.txt"))
    #expect(h.controller.grid.editingIndex == 1)
    #expect(h.controller.grid.editor?.stringValue == "novo nome")
}

@MainActor @Test func pastedItemsAreSelected() async throws {
    let h = try WindowHarness(["A/a.txt", "B/z.txt"], at: "B")
    h.ops.operations.copy([h.ops.url("A/a.txt")])
    h.controller.paste(nil)
    await h.settle()
    #expect(h.selectedNames == ["a.txt"])
}

@MainActor @Test func desktopPasteGoesToTheDesktopFolder() async throws {
    let h = try WindowHarness(["A/a.txt", "Desktop"])
    h.ops.operations.copy([h.ops.url("A/a.txt")])
    h.controller.paste(nil)
    await h.settle()
    #expect(h.ops.exists("Desktop/a.txt"))
    #expect(h.selectedNames == ["a.txt"])
}

@MainActor @Test func cutItemsLookDimmed() throws {
    let h = try WindowHarness(["A/a.txt", "A/b.txt"], at: "A")
    h.ops.operations.cut([h.ops.url("A/a.txt")])
    let grid = h.controller.grid
    let a = try #require(h.index(of: "a.txt")), b = try #require(h.index(of: "b.txt"))
    #expect(h.controller.grid(grid, isDimmedAt: a))
    #expect(!h.controller.grid(grid, isDimmedAt: b))
}

// MARK: Context menus

@MainActor @Test func contextMenuOnBackgroundOffersPasteAndNewFolder() throws {
    let h = try WindowHarness(["A/a.txt", "B"], at: "B")
    h.ops.operations.copy([h.ops.url("A/a.txt")])
    let items = h.controller.contextMenuItems(at: nil).filter { !$0.title.isEmpty }
    #expect(items.map(\.title) == ["Colar", "Mover para cá", "Nova pasta", "Atualizar"])
    #expect(items.allSatisfy { $0.isEnabled })
}

@MainActor @Test func trashViewOffersRestoreAndEmpty() async throws {
    let h = try WindowHarness(["A/a.txt", "A/b.txt"], at: "A")
    h.ops.prompter.answers = [0]
    await h.ops.operations.trash([h.ops.url("A/a.txt")])
    try Data().write(to: h.ops.url(".Trash/outro.txt"))   // trashed by another app: origin unknown
    h.controller.model.go(to: .trash)
    let restore = { (name: String) in
        h.select(name)   // a right-click selects the item before the menu opens
        return h.controller.contextMenuItems(at: h.index(of: name)).first { $0.title == "Restaurar" }
    }
    #expect(restore("a.txt")?.isEnabled == true)
    #expect(restore("outro.txt")?.isEnabled == false)
    let background = h.controller.contextMenuItems(at: nil).map(\.title)
    #expect(background.contains("Esvaziar Lixeira") && background.contains("Abrir no Finder"))
}

/// ⌘Z typed in the address field (or in a name being edited) belongs to the text, never to the files.
@MainActor @Test func undoWhileTypingLeavesFilesAlone() async throws {
    let h = try WindowHarness(["A/a.txt", "B"], at: "B")
    h.ops.operations.copy([h.ops.url("A/a.txt")])
    h.controller.paste(nil)
    await h.settle()
    let window = h.controller.window
    window.makeFirstResponder(h.controller.address.field)
    for action in ["undo:", "redo:"] {
        #expect(!window.validateMenuItem(NSMenuItem(title: "", action: Selector(action), keyEquivalent: "")))
        _ = window.perform(Selector(action), with: nil)
    }
    try await Task.sleep(for: .milliseconds(200))
    #expect(h.ops.exists("B/a.txt"))
    #expect(h.ops.operations.undoStack.canUndo)
    window.makeFirstResponder(h.controller.grid)
    #expect(window.validateMenuItem(NSMenuItem(title: "", action: Selector(("undo:")), keyEquivalent: "")))
}
