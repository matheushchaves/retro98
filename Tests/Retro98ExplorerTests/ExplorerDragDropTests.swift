import AppKit
import Testing
@testable import Retro98Explorer
@testable import Retro98FilesCore
import Retro98UI

private let pt = ["pt-BR"]

@MainActor private final class DropHarness {
    let ops: OperationsHarness
    let controller: ExplorerWindowController

    init(_ paths: [String], start: (OperationsHarness) -> Location) throws {
        let ops = try OperationsHarness(paths)
        self.ops = ops
        controller = ExplorerWindowController(start: start(ops), languages: pt, environment: ops.operations.environment,
                                              operations: ops.operations)
    }

    func index(of name: String) -> Int? { controller.model.entries.firstIndex { $0.name == name } }

    func plan(_ paths: [String], on name: String?, copy: Bool = false, move: Bool = false) -> DropPlan? {
        controller.dropPlan(for: paths.map(ops.url), onItem: name.flatMap(index(of:)), forceCopy: copy, forceMove: move)
    }
}

@MainActor @Test func dropPlansFollowTheItemUnderThePointer() throws {
    let h = try DropHarness(["A/a.txt", "B/Pasta", "B/z.txt", "B/x.txt"]) { .folder($0.url("B")) }
    #expect(h.plan(["A/a.txt"], on: "Pasta") == .transfer(.move, into: h.ops.url("B/Pasta")))
    #expect(h.plan(["A/a.txt"], on: "z.txt") == .transfer(.move, into: h.ops.url("B")))
    #expect(h.plan(["B/x.txt"], on: "z.txt") == nil)
    #expect(h.plan(["B/Pasta"], on: "Pasta") == nil)
    #expect(h.plan(["B/x.txt"], on: nil, copy: true) == .transfer(.copy, into: h.ops.url("B")))

    let desktop = try DropHarness(["Desktop/a.txt", "Documents"]) { _ in .desktop }
    #expect(desktop.plan(["Desktop/a.txt"], on: "Lixeira") == .trash)
    #expect(desktop.plan(["Desktop/a.txt"], on: "Meus Documentos") == .transfer(.move, into: desktop.ops.url("Documents")))

    let computer = try DropHarness(["A/a.txt"]) { _ in .myComputer }
    #expect(computer.plan(["A/a.txt"], on: nil) == nil)
}

@MainActor @Test func droppingOnTheRecycleBinAsksFirst() async throws {
    let h = try DropHarness(["Desktop/a.txt"]) { _ in .desktop }
    h.ops.prompter.answers = [1]
    _ = await h.controller.performDrop(.trash, urls: [h.ops.url("Desktop/a.txt")])
    #expect(h.ops.exists("Desktop/a.txt"))
    h.ops.prompter.answers = [0]
    _ = await h.controller.performDrop(.trash, urls: [h.ops.url("Desktop/a.txt")])
    #expect(!h.ops.exists("Desktop/a.txt") && h.ops.exists(".Trash/a.txt"))
    #expect(h.ops.prompter.asked.first == Prompts.trash(names: ["a.txt"], languages: pt))
}

@MainActor @Test func droppedItemsAreSelected() async throws {
    let h = try DropHarness(["A/a.txt", "B/z.txt"]) { .folder($0.url("B")) }
    let results = await h.controller.performDrop(.transfer(.copy, into: h.ops.url("B")), urls: [h.ops.url("A/a.txt")])
    #expect(results.map(\.lastPathComponent) == ["a.txt"])
    #expect(h.controller.grid.selection.map { h.controller.model.entries[$0].name } == ["a.txt"])
}

@MainActor @Test func onlyFilesAreDraggable() throws {
    let h = try DropHarness(["Desktop/a.txt"]) { _ in .desktop }
    let grid = h.controller.grid
    let file = try #require(h.index(of: "a.txt")), computer = try #require(h.index(of: "Meu Computador"))
    #expect((h.controller.grid(grid, pasteboardWriterAt: file) as? NSURL)?.path == h.ops.url("Desktop/a.txt").path)
    #expect(h.controller.grid(grid, pasteboardWriterAt: computer) == nil)
    #expect(grid.registeredDraggedTypes.contains(.fileURL))
}
