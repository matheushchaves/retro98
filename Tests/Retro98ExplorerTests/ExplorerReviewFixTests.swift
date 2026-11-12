import AppKit
import Testing
@testable import Retro98Explorer
@testable import Retro98FilesCore
import Retro98UI

private let pt = ["pt-BR"]

@MainActor private func window(_ ops: OperationsHarness, at location: Location, searching: Bool = false) -> ExplorerWindowController {
    ExplorerWindowController(start: location, languages: pt, environment: ops.operations.environment, operations: ops.operations,
                             searching: searching)
}

@MainActor private func select(_ controller: ExplorerWindowController, _ names: String...) {
    controller.grid.setSelection(IndexSet(names.compactMap { name in controller.model.entries.firstIndex { $0.name == name } }))
}

/// Details at the default window size scrolls sideways, and the header follows the grid's width and scroll.
@MainActor @Test func detailsScrollsSidewaysAndHeaderFollows() throws {
    let ops = try OperationsHarness((0..<60).map { "A/f\($0).txt" })
    let controller = window(ops, at: .folder(ops.url("A")))
    controller.showDetails(nil)
    let scroll = controller.gridPane.scroll
    #expect(scroll.hasHorizontalScroller)
    #expect(controller.grid.frame.width >= 520)
    #expect(controller.gridPane.header.contentWidth == controller.grid.frame.width)
    scroll.contentView.scroll(to: CGPoint(x: 40, y: 0))
    #expect(controller.gridPane.header.scrollOffset == 40)
}

/// A Properties window must still close after the Explorer window that opened it is gone.
@MainActor @Test func propertiesOutliveTheirWindow() throws {
    let ops = try OperationsHarness(["A/a.txt"])
    weak var properties: PropertiesWindow?
    let controller = window(ops, at: .folder(ops.url("A")))
    select(controller, "a.txt")
    controller.showProperties(nil)
    properties = controller.propertiesWindows.last
    controller.propertiesWindows.removeAll()   // what happens when the Explorer window that owns it goes away
    let open = try #require(properties)
    open.window.cancelOperation(nil)
    #expect(!open.window.isVisible)
}

@MainActor @Test func propertiesOfAnAppShowItsSize() async throws {
    let ops = try OperationsHarness(["A/Calc.app/Contents"])
    try Data(repeating: 65, count: 5000).write(to: ops.url("A/Calc.app/Contents/binario"))
    let controller = window(ops, at: .folder(ops.url("A")))
    controller.grid.setSelection([0])
    controller.showProperties(nil)
    let properties = try #require(controller.propertiesWindows.last)
    await properties.measuring?.value
    #expect(properties.text(of: "Tamanho:") == PropertiesText.size(5000, locale: .current, languages: pt))
    #expect(properties.text(of: "Contém:") == nil)
}

@MainActor @Test func searchResultsFollowFileOperations() async throws {
    let ops = try OperationsHarness(["A/rel.txt", "A/Sub/rel2.txt"])
    let controller = window(ops, at: .folder(ops.url("A")))
    controller.showSearch(nil)
    controller.search(text: "rel", includeSubfolders: true)
    await controller.searchTask?.value
    controller.window.makeFirstResponder(controller.grid)   // clicking a result takes the keyboard from the search field
    select(controller, "rel2.txt")
    ops.prompter.answers = [0]
    controller.moveToTrash(nil)
    await controller.lastTask?.value
    #expect(controller.model.entries.map(\.name) == ["rel.txt"])
    let entry = try #require(controller.model.entries.first)
    let renamed = try #require(await ops.operations.rename(entry, to: "relatorio.txt"))
    controller.showResults([renamed])
    #expect(controller.model.entries.map(\.name) == ["relatorio.txt"])
}

@MainActor @Test func vanishedSearchFolderClosesTheSearch() throws {
    let ops = try OperationsHarness(["A/B/rel.txt", "A/outro.txt"])
    let controller = window(ops, at: .folder(ops.url("A/B")))
    controller.showSearch(nil)
    controller.search(text: "rel", includeSubfolders: false)
    try FileManager.default.removeItem(at: ops.url("A/B"))
    controller.model.reload()
    #expect(controller.model.history.current == .folder(ops.url("A")))
    #expect(controller.model.search == nil)
    #expect(controller.searchBar.isHidden)
    #expect(controller.model.entries.map(\.name) == ["outro.txt"])
}

/// "Show in Finder" scrolls to what it selects.
@MainActor @Test func revealScrollsToTheItem() throws {
    let ops = try OperationsHarness((0..<300).map { String(format: "A/f%03d.txt", $0) })
    let app = AppDelegate(environment: ops.operations.environment, operations: ops.operations)
    app.presentsWindows = false
    app.reveal([ops.url("A/f299.txt")])
    let controller = try #require(app.windowControllers.first)
    let index = try #require(controller.grid.selection.first)
    #expect(controller.grid.visibleRect.intersects(controller.grid.itemFrame(index)))
}

/// Start › Find… opens with the keyboard in the search field.
@MainActor @Test func findFocusesTheSearchField() throws {
    let ops = try OperationsHarness(["A/a.txt"])
    let controller = window(ops, at: .folder(ops.url("A")), searching: true)
    controller.focusInitialResponder()
    let editor = try #require(controller.window.firstResponder as? NSText)
    #expect((editor.delegate as AnyObject?) === controller.searchBar.field)
}

@MainActor @Test func networkDrivesCanBeEjected() async throws {
    final class Ejected: @unchecked Sendable {
        let lock = NSLock()
        var urls: [URL] = []
        func add(_ url: URL) { lock.withLock { urls.append(url) } }
    }
    let ejected = Ejected()
    let share = VolumeInfo(url: URL(filePath: "/Volumes/Rede"), name: "Rede", kind: .network, totalBytes: 100, freeBytes: 50,
                           isEjectable: false)
    let ops = try OperationsHarness([], volumes: [share], services: .fake(eject: { ejected.add($0) }))
    let controller = window(ops, at: .myComputer)
    select(controller, "Rede")
    #expect(controller.isEnabled(#selector(ExplorerWindowController.ejectSelection(_:))))
    controller.ejectSelection(nil)
    await controller.lastTask?.value
    #expect(ejected.lock.withLock { ejected.urls } == [share.url])
}
