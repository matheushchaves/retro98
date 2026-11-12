import Foundation
import Testing
@testable import Retro98FilesCore

/// Collects values from @Sendable callbacks.
private final class Recorder<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: [Value] = []
    var values: [Value] { lock.withLock { stored } }
    func append(_ value: Value) { lock.withLock { stored.append(value) } }
}

private func operations(_ tree: TempTree, sameVolume: Bool = true, refuseTrash: Bool = false) -> FileOperations {
    var refuse: (@Sendable (URL) throws -> URL)?
    if refuseTrash { refuse = { _ in throw CocoaError(.fileWriteNoPermission) } }
    var volume: (@Sendable (URL, URL) -> Bool)?
    if !sameVolume { volume = { _, _ in false } }
    return FileOperations(environment: ExplorerEnvironment(
        home: tree.root, languages: ["pt-BR"], showHidden: false, volumes: { [] }, trash: tree.url(".Trash"),
        moveToTrash: refuse, isSameVolume: volume))
}

private func write(_ url: URL, _ text: String) throws {
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try Data(text.utf8).write(to: url)
}

private func read(_ url: URL) -> String? { (try? Data(contentsOf: url)).map { String(decoding: $0, as: UTF8.self) } }
private func exists(_ url: URL) -> Bool { (try? FileManager.default.attributesOfItem(atPath: url.path)) != nil }
private func inode(_ url: URL) -> UInt64 { var info = stat(); lstat(url.path, &info); return info.st_ino }

private func transfer(_ ops: FileOperations, _ kind: FileOperationKind, _ items: [URL], to destination: URL,
                      control: OperationControl = OperationControl(),
                      resolve: @Sendable (FileConflict) -> ConflictChoice = { _ in .replace },
                      progress: @Sendable (OperationProgress) -> Void = { _ in }) -> OperationOutcome {
    ops.transfer(TransferRequest(kind: kind, items: items, destination: destination), control: control, resolve: resolve, progress: progress)
}

// MARK: Copy and move

@Test func copiesIntoAnotherFolder() throws {
    let tree = try TempTree(["B"])
    try write(tree.url("A/a.txt"), "olá")
    let outcome = transfer(operations(tree), .copy, [tree.url("A/a.txt")], to: tree.url("B"))
    #expect(outcome == OperationOutcome(changes: [.created(tree.url("B/a.txt"))]))
    #expect(read(tree.url("B/a.txt")) == "olá")
    #expect(read(tree.url("A/a.txt")) == "olá")
    #expect(outcome.results == [tree.url("B/a.txt")])
}

@Test func copyIntoTheSameFolderMakesACopyName() throws {
    let tree = try TempTree([])
    try write(tree.url("A/foto.jpg"), "x")
    let outcome = transfer(operations(tree), .copy, [tree.url("A/foto.jpg")], to: tree.url("A"), resolve: { _ in .cancel })
    #expect(outcome == OperationOutcome(changes: [.created(tree.url("A/foto cópia.jpg"))]))
}

@Test func copiesFoldersWithLinksAndAttributes() throws {
    let tree = try TempTree(["A/Pasta/vazia", "B"])
    let deep = tree.url("A/Pasta/sub/deep.txt")
    try write(deep, "fundo")
    try FileManager.default.createSymbolicLink(atPath: tree.url("A/Pasta/link").path, withDestinationPath: "sub/deep.txt")
    let value = Array("sim".utf8)
    #expect(setxattr(deep.path, "io.retro98.test", value, value.count, 0, 0) == 0)

    let outcome = transfer(operations(tree), .copy, [tree.url("A/Pasta")], to: tree.url("B"))
    #expect(outcome.failure == nil)
    #expect(read(tree.url("B/Pasta/sub/deep.txt")) == "fundo")
    #expect(exists(tree.url("B/Pasta/vazia")))
    #expect(try FileManager.default.destinationOfSymbolicLink(atPath: tree.url("B/Pasta/link").path) == "sub/deep.txt")
    #expect(getxattr(tree.url("B/Pasta/sub/deep.txt").path, "io.retro98.test", nil, 0, 0, 0) == value.count)
}

@Test func moveOnTheSameVolumeRenames() throws {
    let tree = try TempTree(["B"])
    try write(tree.url("A/a.txt"), "x")
    let before = inode(tree.url("A/a.txt"))
    let outcome = transfer(operations(tree), .move, [tree.url("A/a.txt")], to: tree.url("B"))
    #expect(outcome == OperationOutcome(changes: [.moved(from: tree.url("A/a.txt"), to: tree.url("B/a.txt"))]))
    #expect(inode(tree.url("B/a.txt")) == before)
    #expect(!exists(tree.url("A/a.txt")))
}

@Test func moveAcrossVolumesCopiesThenRemoves() throws {
    let tree = try TempTree(["B"])
    try write(tree.url("A/Pasta/a.txt"), "x")
    let outcome = transfer(operations(tree, sameVolume: false), .move, [tree.url("A/Pasta")], to: tree.url("B"))
    #expect(outcome == OperationOutcome(changes: [.moved(from: tree.url("A/Pasta"), to: tree.url("B/Pasta"))]))
    #expect(read(tree.url("B/Pasta/a.txt")) == "x")
    #expect(!exists(tree.url("A/Pasta")))
}

// MARK: Conflicts

@Test func conflictReplacesIntoTheTrash() throws {
    let tree = try TempTree([])
    try write(tree.url("A/a.txt"), "novo")
    try write(tree.url("B/a.txt"), "velho")
    let conflicts = Recorder<FileConflict>()
    let outcome = transfer(operations(tree), .copy, [tree.url("A/a.txt")], to: tree.url("B"),
                           resolve: { conflicts.append($0); return .replace })
    #expect(conflicts.values == [FileConflict(source: tree.url("A/a.txt"), existing: tree.url("B/a.txt"), remaining: 0)])
    #expect(outcome == OperationOutcome(changes: [.trashed(original: tree.url("B/a.txt"), trashed: tree.url(".Trash/a.txt")),
                                                  .created(tree.url("B/a.txt"))]))
    #expect(read(tree.url("B/a.txt")) == "novo")
    #expect(read(tree.url(".Trash/a.txt")) == "velho")
}

@Test func replaceAllAsksOnce() throws {
    let tree = try TempTree([])
    for name in ["1", "2", "3"] {
        try write(tree.url("A/\(name).txt"), "novo")
        try write(tree.url("B/\(name).txt"), "velho")
    }
    let asked = Recorder<Int>()
    let outcome = transfer(operations(tree), .copy, ["1", "2", "3"].map { tree.url("A/\($0).txt") }, to: tree.url("B"),
                           resolve: { asked.append($0.remaining); return .replaceAll })
    #expect(asked.values == [2])
    #expect(outcome.failure == nil)
    #expect(["1", "2", "3"].allSatisfy { read(tree.url("B/\($0).txt")) == "novo" })
}

@Test func skipKeepsTheExistingItem() throws {
    let tree = try TempTree([])
    try write(tree.url("A/a.txt"), "novo")
    try write(tree.url("B/a.txt"), "velho")
    let outcome = transfer(operations(tree), .copy, [tree.url("A/a.txt")], to: tree.url("B"), resolve: { _ in .skip })
    #expect(outcome == OperationOutcome())
    #expect(read(tree.url("B/a.txt")) == "velho")
}

@Test func cancelStopsBeforeTheNextItem() throws {
    let tree = try TempTree([])
    for name in ["1", "2", "3"] { try write(tree.url("A/\(name).txt"), "novo") }
    try write(tree.url("B/2.txt"), "velho")
    let outcome = transfer(operations(tree), .copy, ["1", "2", "3"].map { tree.url("A/\($0).txt") }, to: tree.url("B"),
                           resolve: { _ in .cancel })
    #expect(outcome == OperationOutcome(changes: [.created(tree.url("B/1.txt"))], failure: .cancelled))
    #expect(!exists(tree.url("B/3.txt")))
    #expect(read(tree.url("B/2.txt")) == "velho")
}

// MARK: Dangerous destinations

@Test func cannotCopyAFolderIntoItself() throws {
    let tree = try TempTree(["A/Sub"])
    let outcome = transfer(operations(tree), .copy, [tree.url("A")], to: tree.url("A/Sub"))
    #expect(outcome == OperationOutcome(failure: .intoItself(tree.url("A"))))
    #expect(try FileManager.default.contentsOfDirectory(atPath: tree.url("A/Sub").path).isEmpty)
}

@Test func replacingAnAncestorOfTheSourceIsRefused() throws {
    let tree = try TempTree([])
    try write(tree.url("A/B/A/x.txt"), "x")
    let outcome = transfer(operations(tree), .move, [tree.url("A/B/A")], to: tree.root, resolve: { _ in .replace })
    #expect(outcome == OperationOutcome(failure: .replacesItsOwnSource(tree.root.appending(path: "A"))))
    #expect(read(tree.url("A/B/A/x.txt")) == "x")
    #expect(((try? FileManager.default.contentsOfDirectory(atPath: tree.url(".Trash").path)) ?? []).isEmpty)
}

// MARK: Interruptions

private func fiftyFiles(_ tree: TempTree) throws {
    for index in 0..<50 { try write(tree.url("A/Pasta/f\(index).txt"), String(repeating: "x", count: 10)) }
}

@Test func cancellingMidCopyRemovesThePartialItem() throws {
    let tree = try TempTree(["B"])
    try fiftyFiles(tree)
    let control = OperationControl(), seen = Recorder<Int64>()
    let outcome = transfer(operations(tree), .copy, [tree.url("A/Pasta")], to: tree.url("B"), control: control,
                           progress: { seen.append($0.completed); if seen.values.count == 5 { control.cancel() } })
    #expect(outcome == OperationOutcome(failure: .cancelled))
    #expect(!exists(tree.url("B/Pasta")))
}

@Test func cancellingAMoveAcrossVolumesKeepsTheSource() throws {
    let tree = try TempTree(["B"])
    try fiftyFiles(tree)
    let control = OperationControl(), seen = Recorder<Int64>()
    let outcome = transfer(operations(tree, sameVolume: false), .move, [tree.url("A/Pasta")], to: tree.url("B"), control: control,
                           progress: { seen.append($0.completed); if seen.values.count == 5 { control.cancel() } })
    #expect(outcome == OperationOutcome(failure: .cancelled))
    #expect(try FileManager.default.contentsOfDirectory(atPath: tree.url("A/Pasta").path).count == 50)
    #expect(!exists(tree.url("B/Pasta")))
}

@Test func failureMidCopyRemovesThePartialItem() throws {
    let tree = try TempTree(["B"])
    try write(tree.url("A/Pasta/ok.txt"), "x")
    try write(tree.url("A/Pasta/Trancada/x.txt"), "x")
    let locked = tree.url("A/Pasta/Trancada").path
    try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: locked)
    defer { try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: locked) }
    let outcome = transfer(operations(tree), .copy, [tree.url("A/Pasta")], to: tree.url("B"))
    guard case .failed(let item, let reason) = outcome.failure else {
        Issue.record("expected a failure, got \(String(describing: outcome.failure))")
        return
    }
    #expect(item == tree.url("A/Pasta"))
    #expect(!reason.isEmpty)
    #expect(outcome.changes.isEmpty)
    #expect(!exists(tree.url("B/Pasta")))
}

@Test func progressReachesTheTotal() throws {
    let tree = try TempTree(["B"])
    try write(tree.url("A/a.txt"), String(repeating: "a", count: 100))
    try write(tree.url("A/Sub/b.txt"), String(repeating: "b", count: 50))
    let seen = Recorder<OperationProgress>()
    _ = transfer(operations(tree), .copy, [tree.url("A/a.txt"), tree.url("A/Sub")], to: tree.url("B"), progress: { seen.append($0) })
    let last = try #require(seen.values.last)
    #expect(last.completed == 150)
    #expect(last.total == 150)
}

// MARK: Trash, delete, new folder

@Test func trashRecordsWhereItemsWent() throws {
    let tree = try TempTree(["A/a.txt", "A/Sub"])
    let outcome = operations(tree).trash([tree.url("A/a.txt"), tree.url("A/Sub")], control: OperationControl(), progress: { _ in })
    #expect(outcome == OperationOutcome(changes: [.trashed(original: tree.url("A/a.txt"), trashed: tree.url(".Trash/a.txt")),
                                                  .trashed(original: tree.url("A/Sub"), trashed: tree.url(".Trash/Sub"))]))
    #expect(exists(tree.url(".Trash/a.txt")) && exists(tree.url(".Trash/Sub")))
}

@Test func refusedTrashIsReported() throws {
    let tree = try TempTree(["A/a.txt"])
    let outcome = operations(tree, refuseTrash: true).trash([tree.url("A/a.txt")], control: OperationControl(), progress: { _ in })
    #expect(outcome == OperationOutcome(failure: .cannotTrash([tree.url("A/a.txt")])))
    #expect(exists(tree.url("A/a.txt")))
}

@Test func deletePermanentlyRemoves() throws {
    let tree = try TempTree(["A/a.txt", "A/Sub/b.txt"])
    let outcome = operations(tree).deletePermanently([tree.url("A/a.txt"), tree.url("A/Sub")], control: OperationControl(), progress: { _ in })
    #expect(outcome == OperationOutcome())
    #expect(!exists(tree.url("A/a.txt")) && !exists(tree.url("A/Sub")))
}

@Test func newFolderCountsUp() throws {
    let tree = try TempTree(["A"])
    let ops = operations(tree)
    #expect(ops.newFolder(in: tree.url("A"), languages: ["pt-BR"]) == OperationOutcome(changes: [.created(tree.url("A/Nova pasta"))]))
    #expect(ops.newFolder(in: tree.url("A"), languages: ["pt-BR"]) == OperationOutcome(changes: [.created(tree.url("A/Nova pasta (2)"))]))
}

// MARK: Rename

@Test func renameChangesOnlyTheName() throws {
    let tree = try TempTree([])
    try write(tree.url("A/a.txt"), "x")
    let outcome = operations(tree).rename(tree.url("A/a.txt"), to: "b.txt")
    #expect(outcome == OperationOutcome(changes: [.moved(from: tree.url("A/a.txt"), to: tree.url("A/b.txt"))]))
    #expect(read(tree.url("A/b.txt")) == "x")
}

@Test func renameCaseOnly() throws {
    let tree = try TempTree(["A/a.txt"])
    let outcome = operations(tree).rename(tree.url("A/a.txt"), to: "A.txt")
    #expect(outcome == OperationOutcome(changes: [.moved(from: tree.url("A/a.txt"), to: tree.url("A/A.txt"))]))
    #expect(try FileManager.default.contentsOfDirectory(atPath: tree.url("A").path) == ["A.txt"])
}

@Test func renameOntoAnotherItemFails() throws {
    let tree = try TempTree(["A/a.txt", "A/b.txt"])
    let outcome = operations(tree).rename(tree.url("A/a.txt"), to: "b.txt")
    #expect(outcome == OperationOutcome(failure: .alreadyExists(tree.url("A/b.txt"))))
    #expect(exists(tree.url("A/a.txt")))
}

// MARK: Revert

@Test func revertUndoesAReplace() throws {
    let tree = try TempTree([])
    try write(tree.url("A/a.txt"), "novo")
    try write(tree.url("B/a.txt"), "velho")
    let ops = operations(tree)
    let done = transfer(ops, .copy, [tree.url("A/a.txt")], to: tree.url("B"))
    let reverted = ops.revert(done.changes, control: OperationControl(), progress: { _ in })
    #expect(reverted == OperationOutcome(changes: [.trashed(original: tree.url("B/a.txt"), trashed: tree.url(".Trash/a 2.txt")),
                                                   .moved(from: tree.url(".Trash/a.txt"), to: tree.url("B/a.txt"))]))
    #expect(read(tree.url("B/a.txt")) == "velho")
    #expect(read(tree.url(".Trash/a 2.txt")) == "novo")
}

@Test func revertOfAVanishedItemFails() throws {
    let tree = try TempTree(["B"])
    try write(tree.url("A/a.txt"), "x")
    let ops = operations(tree)
    let done = transfer(ops, .copy, [tree.url("A/a.txt")], to: tree.url("B"))
    try FileManager.default.removeItem(at: tree.url("B/a.txt"))
    let reverted = ops.revert(done.changes, control: OperationControl(), progress: { _ in })
    guard case .failed(let item, _) = reverted.failure else {
        Issue.record("expected a failure, got \(String(describing: reverted.failure))")
        return
    }
    #expect(item == tree.url("B/a.txt"))
    #expect(reverted.changes.isEmpty)
}

// MARK: Final review fixes

/// The same folder reached through a link (or another letter case) is still the same folder.
@Test func copyIntoItsOwnFolderThroughALinkMakesACopy() throws {
    let tree = try TempTree([])
    try write(tree.url("A/a.txt"), "x")
    try FileManager.default.createSymbolicLink(atPath: tree.url("Link").path, withDestinationPath: tree.url("A").path)
    let asked = Recorder<FileConflict>()
    let outcome = transfer(operations(tree), .copy, [tree.url("A/a.txt")], to: tree.url("Link"),
                           resolve: { asked.append($0); return .replace })
    #expect(asked.values.isEmpty)
    #expect(outcome == OperationOutcome(changes: [.created(tree.url("Link/a cópia.txt"))]))
    #expect(read(tree.url("A/a.txt")) == "x")
}

@Test func moveIntoItsOwnFolderThroughALinkDoesNothing() throws {
    let tree = try TempTree([])
    try write(tree.url("A/a.txt"), "x")
    try FileManager.default.createSymbolicLink(atPath: tree.url("Link").path, withDestinationPath: tree.url("A").path)
    let asked = Recorder<FileConflict>()
    let outcome = transfer(operations(tree), .move, [tree.url("A/a.txt")], to: tree.url("Link"),
                           resolve: { asked.append($0); return .replace })
    #expect(asked.values.isEmpty)
    #expect(outcome == OperationOutcome())
    #expect(read(tree.url("A/a.txt")) == "x")
}

@Test func copyIntoACaseVariantOfItsOwnFolderMakesACopy() throws {
    let tree = try TempTree([])
    try write(tree.url("Docs/a.txt"), "x")
    guard FileManager.default.fileExists(atPath: tree.url("docs").path) else { return }   // case-sensitive volume
    let outcome = transfer(operations(tree), .copy, [tree.url("Docs/a.txt")], to: tree.url("docs"), resolve: { _ in .replace })
    #expect(outcome == OperationOutcome(changes: [.created(tree.url("docs/a cópia.txt"))]))
    #expect(read(tree.url("Docs/a.txt")) == "x")
}

@Test func copyIntoItsOwnSubfolderThroughALinkIsRefused() throws {
    let tree = try TempTree(["A/Pasta/sub"])
    try FileManager.default.createSymbolicLink(atPath: tree.url("Link").path, withDestinationPath: tree.url("A").path)
    let outcome = transfer(operations(tree), .copy, [tree.url("A/Pasta")], to: tree.url("Link/Pasta/sub"))
    #expect(outcome == OperationOutcome(failure: .intoItself(tree.url("A/Pasta"))))
}

@Test func replacingAnAncestorThroughALinkIsRefused() throws {
    let tree = try TempTree([])
    try write(tree.url("A/B/A/x.txt"), "x")
    try FileManager.default.createSymbolicLink(atPath: tree.url("Root").path, withDestinationPath: tree.root.path)
    let outcome = transfer(operations(tree), .move, [tree.url("A/B/A")], to: tree.url("Root"), resolve: { _ in .replace })
    #expect(outcome == OperationOutcome(failure: .replacesItsOwnSource(tree.url("Root").appending(path: "A"))))
    #expect(read(tree.url("A/B/A/x.txt")) == "x")
}

/// Cancelling or failing while replacing must leave the old item where it was.
@Test func cancellingAReplaceKeepsTheOldItem() throws {
    let tree = try TempTree([])
    try fiftyFiles(tree)
    try write(tree.url("B/Pasta/importante.txt"), "guardar")
    let control = OperationControl(), seen = Recorder<Int64>()
    let outcome = transfer(operations(tree), .copy, [tree.url("A/Pasta")], to: tree.url("B"), control: control,
                           resolve: { _ in .replace },
                           progress: { seen.append($0.completed); if seen.values.count == 5 { control.cancel() } })
    #expect(outcome.failure == .cancelled)
    #expect(read(tree.url("B/Pasta/importante.txt")) == "guardar")
    #expect(((try? FileManager.default.contentsOfDirectory(atPath: tree.url(".Trash").path)) ?? []).isEmpty)
    #expect(try FileManager.default.contentsOfDirectory(atPath: tree.url("B").path) == ["Pasta"])
}

@Test func failedReplaceKeepsTheOldItem() throws {
    let tree = try TempTree([])
    try write(tree.url("A/Pasta/ok.txt"), "x")
    try write(tree.url("A/Pasta/Trancada/x.txt"), "x")
    try write(tree.url("B/Pasta/importante.txt"), "guardar")
    let locked = tree.url("A/Pasta/Trancada").path
    try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: locked)
    defer { try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: locked) }
    let outcome = transfer(operations(tree), .copy, [tree.url("A/Pasta")], to: tree.url("B"), resolve: { _ in .replace })
    guard case .failed = outcome.failure else {
        Issue.record("expected a failure, got \(String(describing: outcome.failure))")
        return
    }
    #expect(outcome.changes.isEmpty)
    #expect(read(tree.url("B/Pasta/importante.txt")) == "guardar")
    #expect(((try? FileManager.default.contentsOfDirectory(atPath: tree.url(".Trash").path)) ?? []).isEmpty)
    #expect(try FileManager.default.contentsOfDirectory(atPath: tree.url("B").path) == ["Pasta"])
}

@Test func refusedTrashDuringAReplaceKeepsBothItems() throws {
    let tree = try TempTree([])
    try write(tree.url("A/a.txt"), "novo")
    try write(tree.url("B/a.txt"), "velho")
    for kind in [FileOperationKind.copy, .move] {
        let outcome = transfer(operations(tree, refuseTrash: true), kind, [tree.url("A/a.txt")], to: tree.url("B"),
                               resolve: { _ in .replace })
        guard case .failed(let item, _) = outcome.failure else {
            Issue.record("expected a failure, got \(String(describing: outcome.failure))")
            return
        }
        #expect(item == tree.url("B/a.txt"))
        #expect(outcome.changes.isEmpty)
        #expect(read(tree.url("A/a.txt")) == "novo")
        #expect(read(tree.url("B/a.txt")) == "velho")
        #expect(try FileManager.default.contentsOfDirectory(atPath: tree.url("B").path) == ["a.txt"])
    }
}
