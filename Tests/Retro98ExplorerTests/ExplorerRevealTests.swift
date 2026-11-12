import AppKit
import Testing
@testable import Retro98Explorer
@testable import Retro98FilesCore

/// "Show in Finder" from other apps, when the Explorer is the file viewer: a window per folder, items selected.
@MainActor @Test func revealOpensOneWindowPerFolderAndSelects() throws {
    let ops = try OperationsHarness(["X/a.txt", "X/c.txt", "X/z.txt", "Y/b.txt"])
    let app = AppDelegate(environment: ops.operations.environment, operations: ops.operations)
    app.presentsWindows = false
    app.reveal([ops.url("X/a.txt"), ops.url("Y/b.txt"), ops.url("X/c.txt")])
    #expect(app.windowControllers.count == 2)
    func selected(_ folder: String) throws -> [String] {
        let controller = try #require(app.windowControllers.first { $0.model.history.current == .folder(ops.url(folder)) })
        return controller.grid.selection.map { controller.model.entries[$0].name }
    }
    #expect(try selected("X") == ["a.txt", "c.txt"])
    #expect(try selected("Y") == ["b.txt"])
    app.reveal([ops.url("X/z.txt")])
    #expect(app.windowControllers.count == 2)
    #expect(try selected("X") == ["z.txt"])
}

@MainActor @Test func openingFileURLsReveals() throws {
    let ops = try OperationsHarness(["X/a.txt"])
    let app = AppDelegate(environment: ops.operations.environment, operations: ops.operations)
    app.presentsWindows = false
    app.application(NSApplication.shared, open: [ops.url("X/a.txt")])
    #expect(app.windowControllers.count == 1)
    #expect(app.windowControllers.first?.model.history.current == .folder(ops.url("X")))
}
