import Foundation
import Testing
@testable import Retro98FilesCore

private let a = URL(filePath: "/T/a.txt"), b = URL(filePath: "/T/B/a.txt"), t = URL(filePath: "/T/.Trash/a.txt")

// MARK: Undo stack

@MainActor @Test func recordingClearsRedo() async {
    let stack = FileUndoStack()
    stack.record(FileAction(name: .copy, changes: [.created(a)]))
    _ = await stack.undo { _ in OperationOutcome(changes: [.trashed(original: a, trashed: t)]) }
    #expect(stack.canRedo)
    stack.record(FileAction(name: .move, changes: [.moved(from: a, to: b)]))
    #expect(!stack.canRedo)
    #expect(stack.undoName == .move)
}

@MainActor @Test func emptyActionsAreNotRecorded() {
    let stack = FileUndoStack()
    stack.record(FileAction(name: .copy, changes: []))
    #expect(!stack.canUndo)
    #expect(stack.undoName == nil)
}

@MainActor @Test func undoMovesTheActionToRedo() async {
    let stack = FileUndoStack()
    var changes = 0
    stack.onChange = { changes += 1 }
    stack.record(FileAction(name: .copy, changes: [.created(a)]))
    let outcome = await stack.undo { _ in OperationOutcome(changes: [.trashed(original: a, trashed: t)]) }
    #expect(outcome == OperationOutcome(changes: [.trashed(original: a, trashed: t)]))
    #expect(!stack.canUndo)
    #expect(stack.canRedo)
    #expect(stack.redoName == .copy)
    #expect(changes >= 2)
}

@MainActor @Test func redoRunsRevertOnTheUndoResult() async {
    let stack = FileUndoStack()
    stack.record(FileAction(name: .copy, changes: [.created(a)]))
    _ = await stack.undo { _ in OperationOutcome(changes: [.trashed(original: a, trashed: t)]) }
    var received: [FileChange] = []
    _ = await stack.redo { changes in
        received = changes
        return OperationOutcome(changes: [.moved(from: t, to: a)])
    }
    #expect(received == [.trashed(original: a, trashed: t)])
    #expect(stack.undoName == .copy)
    #expect(!stack.canRedo)
}

@MainActor @Test func busyDisablesUndo() async {
    let stack = FileUndoStack()
    stack.record(FileAction(name: .copy, changes: [.created(a)]))
    stack.record(FileAction(name: .move, changes: [.moved(from: a, to: b)]))
    var seenWhileRunning: (busy: Bool, undo: Bool, redo: Bool)?
    _ = await stack.undo { _ in
        seenWhileRunning = (stack.isBusy, stack.canUndo, stack.canRedo)
        return OperationOutcome(changes: [.moved(from: b, to: a)])
    }
    #expect(seenWhileRunning?.busy == true)
    #expect(seenWhileRunning?.undo == false)
    #expect(seenWhileRunning?.redo == false)
    #expect(!stack.isBusy && stack.canUndo)

    stack.beginWork()
    #expect(!stack.canUndo)
    #expect(await stack.undo { _ in OperationOutcome() } == nil)
    stack.endWork()
    #expect(stack.canUndo)
}

@MainActor @Test func failedUndoDropsTheAction() async {
    let stack = FileUndoStack()
    stack.record(FileAction(name: .copy, changes: [.created(a)]))
    let outcome = await stack.undo { _ in OperationOutcome(failure: .failed(a, "sumiu")) }
    #expect(outcome?.failure == .failed(a, "sumiu"))
    #expect(!stack.canUndo)
    #expect(!stack.canRedo)
}

@Test func actionTitles() {
    #expect(ExplorerText.undoTitle(.copy, ["pt-BR"]) == "Desfazer Copiar")
    #expect(ExplorerText.redoTitle(.newFolder, ["pt-BR"]) == "Refazer Nova pasta")
    #expect(ExplorerText.undoTitle(nil, ["pt-BR"]) == "Desfazer")
    #expect(ExplorerText.undoTitle(.restore, ["en"]) == "Undo Restore")
    #expect(ExplorerText.redoTitle(.delete, ["en"]) == "Redo Delete")
}

// MARK: Where trashed items came from

@MainActor @Test func remembersWhereTrashedItemsCameFrom() throws {
    let tree = try TempTree([".Trash/x.txt"])
    let file = tree.url("support/trash-origins.json")
    let origins = TrashOrigins(file: file, trash: tree.url(".Trash"))
    origins.record([.trashed(original: tree.url("A/x.txt"), trashed: tree.url(".Trash/x.txt"))])
    #expect(origins.origin(of: tree.url(".Trash/x.txt")) == tree.url("A/x.txt"))
    #expect(TrashOrigins(file: file, trash: tree.url(".Trash")).origin(of: tree.url(".Trash/x.txt")) == tree.url("A/x.txt"))
}

@MainActor @Test func redoOfARestoreRemembersAgain() throws {
    let tree = try TempTree([".Trash/x.txt", "PEN/.Trashes/501/y.txt"])
    let origins = TrashOrigins(file: tree.url("support/trash-origins.json"), trash: tree.url(".Trash"))
    origins.record([.moved(from: tree.url("A/x.txt"), to: tree.url(".Trash/x.txt")),
                    .moved(from: tree.url("PEN/y.txt"), to: tree.url("PEN/.Trashes/501/y.txt")),
                    .moved(from: tree.url("A/z.txt"), to: tree.url("B/z.txt"))])
    #expect(origins.origin(of: tree.url(".Trash/x.txt")) == tree.url("A/x.txt"))
    #expect(origins.origin(of: tree.url("PEN/.Trashes/501/y.txt")) == tree.url("PEN/y.txt"))
    #expect(origins.origin(of: tree.url("B/z.txt")) == nil)
}

@MainActor @Test func forgetsItemsThatLeftTheTrash() throws {
    let tree = try TempTree([".Trash/x.txt"])
    let file = tree.url("support/trash-origins.json")
    let origins = TrashOrigins(file: file, trash: tree.url(".Trash"))
    origins.record([.trashed(original: tree.url("A/x.txt"), trashed: tree.url(".Trash/x.txt"))])
    try FileManager.default.removeItem(at: tree.url(".Trash/x.txt"))
    #expect(origins.origin(of: tree.url(".Trash/x.txt")) == nil)
    try Data().write(to: tree.url(".Trash/x.txt"))   // something else with the same name later
    #expect(TrashOrigins(file: file, trash: tree.url(".Trash")).origin(of: tree.url(".Trash/x.txt")) == nil)
}

@MainActor @Test func corruptFileStartsEmpty() throws {
    let tree = try TempTree([".Trash/x.txt", "support"])
    let file = tree.url("support/trash-origins.json")
    try Data("não é json".utf8).write(to: file)
    let origins = TrashOrigins(file: file, trash: tree.url(".Trash"))
    #expect(origins.origin(of: tree.url(".Trash/x.txt")) == nil)
    origins.record([.trashed(original: tree.url("A/x.txt"), trashed: tree.url(".Trash/x.txt"))])
    #expect(origins.origin(of: tree.url(".Trash/x.txt")) == tree.url("A/x.txt"))
}
