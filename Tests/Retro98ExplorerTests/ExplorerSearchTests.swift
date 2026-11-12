import AppKit
import Testing
@testable import Retro98Explorer
@testable import Retro98FilesCore
import Retro98UI

private let pt = ["pt-BR"]

@MainActor private func window(_ ops: OperationsHarness, at path: String, searching: Bool = false) -> ExplorerWindowController {
    ExplorerWindowController(start: .folder(ops.url(path)), languages: pt, environment: ops.operations.environment,
                             operations: ops.operations, searching: searching)
}

@MainActor private func names(_ controller: ExplorerWindowController) -> [String] { controller.model.entries.map(\.name) }

@MainActor @Test func searchBarFiltersTheFolderAsYouType() throws {
    let ops = try OperationsHarness(["A/rel.txt", "A/outro.txt", "A/Sub/rel2.txt"])
    let controller = window(ops, at: "A")
    controller.showSearch(nil)
    #expect(!controller.searchBar.isHidden)
    controller.search(text: "rel", includeSubfolders: false)
    #expect(names(controller) == ["rel.txt"])
}

@MainActor @Test func searchInSubfoldersFindsNestedFiles() async throws {
    let ops = try OperationsHarness(["A/rel.txt", "A/outro.txt", "A/Sub/rel2.txt"])
    let controller = window(ops, at: "A")
    controller.showSearch(nil)
    controller.search(text: "rel", includeSubfolders: true)
    await controller.searchTask?.value
    #expect(Set(names(controller)) == ["rel.txt", "rel2.txt"])
    #expect(controller.statusBar.fields.first?.text == "2 objeto(s) encontrado(s)")
    #expect(controller.grid.columns.map(\.title).contains("Em pasta"))
}

@MainActor @Test func navigatingAwayEndsTheSearch() throws {
    let ops = try OperationsHarness((0..<50).map { "A/Sub/rel\($0).txt" })
    let controller = window(ops, at: "A")
    controller.showSearch(nil)
    controller.search(text: "rel", includeSubfolders: true)
    let task = controller.searchTask
    controller.model.go(to: .folder(ops.url("A/Sub")))
    #expect(controller.model.search == nil)
    #expect(controller.searchBar.isHidden)
    #expect(task?.isCancelled == true)
    #expect(names(controller).count == 50)
}

@MainActor @Test func escapeClosesTheSearch() throws {
    let ops = try OperationsHarness(["A/rel.txt", "A/outro.txt"])
    let controller = window(ops, at: "A")
    controller.showSearch(nil)
    controller.search(text: "rel", includeSubfolders: false)
    let escape = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: controller.window.windowNumber,
                                  context: nil, characters: "\u{1b}", charactersIgnoringModifiers: "\u{1b}", isARepeat: false, keyCode: 53)!
    controller.grid.keyDown(with: escape)
    #expect(controller.searchBar.isHidden)
    #expect(controller.model.search == nil)
    #expect(names(controller) == ["outro.txt", "rel.txt"])
}

@MainActor @Test func searchRequestOpensSearching() throws {
    let ops = try OperationsHarness(["A/rel.txt"])
    let controller = window(ops, at: "A", searching: true)
    #expect(!controller.searchBar.isHidden)
    #expect(controller.searchBar.includeSubfolders.isOn)
}

@MainActor @Test func menusHaveTheSearchShortcut() {
    let items = ExplorerMenus.mainMenu(languages: pt).items.flatMap { $0.submenu?.items ?? [] }
    #expect(items.contains { $0.keyEquivalent == "f" && $0.keyEquivalentModifierMask == .command && $0.action.map(NSStringFromSelector) == "showSearch:" })
}
