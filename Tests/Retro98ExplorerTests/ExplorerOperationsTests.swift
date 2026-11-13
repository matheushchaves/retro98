import AppKit
import Testing
@testable import Retro98Explorer
@testable import Retro98FilesCore
import Retro98UI

private let pt = ["pt-BR"]

/// Answers prompts from a queue (default: the last button, like Esc) and remembers what was asked.
@MainActor final class ScriptedPrompter: ExplorerPrompter {
    var answers: [Int] = []
    var onAsk: ((Prompt) -> Void)?
    private(set) var asked: [Prompt] = []

    func ask(_ prompt: Prompt) -> Int {
        asked.append(prompt)
        onAsk?(prompt)
        return answers.isEmpty ? prompt.buttons.count - 1 : answers.removeFirst()
    }
}

extension ExplorerServices {
    /// Never ejects or opens anything; tests pass their own closures when they need them.
    static func fake(eject: @escaping @Sendable (URL) throws -> Void = { _ in },
                     applications: @escaping @Sendable (URL) -> (default: URL?, all: [URL]) = { _ in (nil, []) },
                     open: @escaping @Sendable ([URL], URL) -> Void = { _, _ in }) -> ExplorerServices {
        ExplorerServices(eject: eject, applications: applications, open: open)
    }
}

/// Operations on a temp tree with a private pasteboard and scripted prompts.
@MainActor final class OperationsHarness {
    let tree: TempTree
    let prompter = ScriptedPrompter()
    let pasteboard = NSPasteboard(name: NSPasteboard.Name("retro98-test-\(UUID().uuidString)"))
    let operations: ExplorerOperations
    private(set) var sounds: [RetroSoundKind] = []

    init(_ paths: [String], refuseTrash: Bool = false, progressDelay: TimeInterval = .infinity,
         volumes: [VolumeInfo] = [], services: ExplorerServices = .fake()) throws {
        tree = try TempTree(paths + [".Trash"])
        var refuse: (@Sendable (URL) throws -> URL)?
        if refuseTrash { refuse = { _ in throw CocoaError(.fileWriteNoPermission) } }
        let environment = ExplorerEnvironment(home: tree.root, languages: pt, showHidden: false, volumes: { volumes },
                                              trash: tree.url(".Trash"), moveToTrash: refuse)
        var recorded: (RetroSoundKind) -> Void = { _ in }
        operations = ExplorerOperations(environment: environment, pasteboard: pasteboard, prompter: prompter,
                                        progressDelay: progressDelay, services: services, playSound: { recorded($0) })
        recorded = { [unowned self] in self.sounds.append($0) }
    }

    func url(_ path: String) -> URL { tree.url(path) }
    func exists(_ path: String) -> Bool { FileManager.default.fileExists(atPath: tree.url(path).path) }

    var pastedURLs: [URL] {
        (pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL]) ?? []
    }

    deinit { MainActor.assumeIsolated { pasteboard.releaseGlobally() } }
}

// MARK: Clipboard

@MainActor @Test func copyWritesFileURLsTheFinderReads() throws {
    let h = try OperationsHarness(["A/a.txt"])
    h.operations.copy([h.url("A/a.txt")])
    #expect(h.pastedURLs.map(\.path) == [h.url("A/a.txt").path])
    #expect(h.operations.canPaste)
}

@MainActor @Test func pasteReadsWhatTheFinderCopied() async throws {
    let h = try OperationsHarness(["A/a.txt", "B"])
    h.pasteboard.clearContents()
    h.pasteboard.writeObjects([h.url("A/a.txt") as NSURL])
    let results = await h.operations.paste(into: h.url("B"))
    #expect(results.map(\.path) == [h.url("B/a.txt").path])
    #expect(h.exists("A/a.txt") && h.exists("B/a.txt"))
}

@MainActor @Test func cutThenPasteMoves() async throws {
    let h = try OperationsHarness(["A/a.txt", "B"])
    h.operations.cut([h.url("A/a.txt")])
    #expect(h.operations.isCut(h.url("A/a.txt")))
    _ = await h.operations.paste(into: h.url("B"))
    #expect(!h.exists("A/a.txt") && h.exists("B/a.txt"))
    #expect(!h.operations.canPaste)
    #expect(!h.operations.isCut(h.url("A/a.txt")))
}

@MainActor @Test func cutIsForgottenWhenSomethingElseIsCopied() async throws {
    let h = try OperationsHarness(["A/a.txt", "B"])
    h.operations.cut([h.url("A/a.txt")])
    h.pasteboard.clearContents()
    h.pasteboard.writeObjects([h.url("A/a.txt") as NSURL])   // another app copied the same file
    #expect(!h.operations.isCut(h.url("A/a.txt")))
    _ = await h.operations.paste(into: h.url("B"))
    #expect(h.exists("A/a.txt") && h.exists("B/a.txt"))
}

@MainActor @Test func moveItemHereMovesCopiedFiles() async throws {
    let h = try OperationsHarness(["A/a.txt", "B"])
    h.operations.copy([h.url("A/a.txt")])
    _ = await h.operations.paste(into: h.url("B"), forceMove: true)
    #expect(!h.exists("A/a.txt") && h.exists("B/a.txt"))
}

// MARK: Trash

@MainActor @Test func trashAsksFirst() async throws {
    let h = try OperationsHarness(["A/a.txt"])
    h.prompter.answers = [1]
    await h.operations.trash([h.url("A/a.txt")])
    #expect(h.exists("A/a.txt"))
    #expect(h.prompter.asked == [Prompts.trash(names: ["a.txt"], languages: pt)])
    h.prompter.answers = [0]
    await h.operations.trash([h.url("A/a.txt")])
    #expect(!h.exists("A/a.txt") && h.exists(".Trash/a.txt"))
    #expect(h.operations.canRestore(h.url(".Trash/a.txt")))
}

@MainActor @Test func refusedTrashOffersPermanentDelete() async throws {
    let h = try OperationsHarness(["A/a.txt"], refuseTrash: true)
    h.prompter.answers = [0, 0]
    await h.operations.trash([h.url("A/a.txt")])
    #expect(!h.exists("A/a.txt"))
    #expect(h.prompter.asked.last == Prompts.cannotTrash(names: ["a.txt"], languages: pt))
}

@MainActor @Test func emptyTrashAsksAndClearsUndo() async throws {
    let h = try OperationsHarness(["A/a.txt"])
    h.prompter.answers = [0]
    await h.operations.trash([h.url("A/a.txt")])
    #expect(h.operations.undoStack.canUndo)
    h.prompter.answers = [0]
    await h.operations.emptyTrash(count: 1)
    #expect(h.prompter.asked.last == Prompts.emptyTrash(count: 1, languages: pt))
    #expect(try FileManager.default.contentsOfDirectory(atPath: h.url(".Trash").path).isEmpty)
    #expect(!h.operations.undoStack.canUndo)
}

@MainActor @Test func emptyingTrashPlaysTheSound() async throws {
    let h = try OperationsHarness(["A/a.txt"])
    h.prompter.answers = [0]
    await h.operations.trash([h.url("A/a.txt")])
    h.prompter.answers = [1]
    await h.operations.emptyTrash(count: 1)
    #expect(h.sounds.isEmpty)
    h.prompter.answers = [0]
    await h.operations.emptyTrash(count: 1)
    #expect(h.sounds == [.emptyTrash])
    #expect(try FileManager.default.contentsOfDirectory(atPath: h.url(".Trash").path).isEmpty)
}

@MainActor @Test func restorePutsItemsBack() async throws {
    let h = try OperationsHarness(["A/a.txt"])
    h.prompter.answers = [0]
    await h.operations.trash([h.url("A/a.txt")])
    let restored = await h.operations.restore([h.url(".Trash/a.txt")])
    #expect(restored.map(\.path) == [h.url("A/a.txt").path])
    #expect(h.exists("A/a.txt"))
    #expect(!h.operations.canRestore(h.url(".Trash/a.txt")))
}

// MARK: Undo

@MainActor @Test func undoAfterPasteSendsTheCopyToTheTrash() async throws {
    let h = try OperationsHarness(["A/a.txt", "B"])
    h.operations.copy([h.url("A/a.txt")])
    _ = await h.operations.paste(into: h.url("B"))
    #expect(h.operations.undoManager.canUndo)
    #expect(h.operations.undoManager.undoMenuItemTitle == "Desfazer Copiar")
    await h.operations.undo()
    #expect(!h.exists("B/a.txt") && h.exists(".Trash/a.txt"))
    #expect(h.operations.undoManager.redoMenuItemTitle == "Refazer Copiar")
}

@MainActor @Test func redoBringsItBack() async throws {
    let h = try OperationsHarness(["A/a.txt", "B"])
    h.operations.copy([h.url("A/a.txt")])
    _ = await h.operations.paste(into: h.url("B"))
    await h.operations.undo()
    await h.operations.redo()
    #expect(h.exists("B/a.txt") && !h.exists(".Trash/a.txt"))
    #expect(h.operations.undoManager.undoMenuItemTitle == "Desfazer Copiar")
}

@MainActor @Test func undoWithoutTrashAccessExplains() async throws {
    let h = try OperationsHarness(["A/a.txt"])
    h.prompter.answers = [0]
    await h.operations.trash([h.url("A/a.txt")])
    let trash = h.url(".Trash").path
    try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: trash)
    defer { try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: trash) }
    await h.operations.undo()
    let shown = try #require(h.prompter.asked.last)
    #expect(shown.title == "Erro ao desfazer")
    #expect(shown.message.contains(ExplorerText.trashAccessHint(pt)))
    #expect(!h.exists("A/a.txt"))
}

// MARK: Conflicts and failures

@Test func conflictPromptShowsBothItems() throws {
    let saoPaulo = try #require(TimeZone(identifier: "America/Sao_Paulo"))
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = saoPaulo
    let older = try #require(calendar.date(from: DateComponents(year: 2026, month: 11, day: 10, hour: 14, minute: 32)))
    let newer = try #require(calendar.date(from: DateComponents(year: 2026, month: 11, day: 11, hour: 9, minute: 10)))
    let conflict = FileConflict(source: URL(filePath: "/A/a.txt"), existing: URL(filePath: "/B/a.txt"), remaining: 0)
    let prompt = Prompts.replace(conflict, existing: (size: 10, modified: older), incoming: (size: 5, modified: newer),
                                 languages: pt, locale: Locale(identifier: "pt_BR"), timeZone: saoPaulo)
    #expect(prompt.title == "Substituir arquivo")
    #expect(prompt.message.hasPrefix("Esta pasta já contém um item chamado 'a.txt'."))
    for piece in ["10 bytes", "10/11/2026", "14:32", "5 bytes", "11/11/2026", "09:10"] { #expect(prompt.message.contains(piece)) }
    #expect(prompt.message.range(of: "10 bytes")!.lowerBound < prompt.message.range(of: "5 bytes")!.lowerBound)
    #expect(prompt.buttons == ["Sim", "Não"])
    let many = Prompts.replace(FileConflict(source: conflict.source, existing: conflict.existing, remaining: 2),
                               existing: (size: nil, modified: nil), incoming: (size: nil, modified: nil),
                               languages: pt, locale: Locale(identifier: "pt_BR"), timeZone: saoPaulo)
    #expect(many.buttons == ["Sim", "Sim para todos", "Não", "Cancelar"])
}

@MainActor @Test func conflictPromptIsAskedAndNoKeepsTheItem() async throws {
    let h = try OperationsHarness(["B"])
    try Data("novo".utf8).write(to: { try? FileManager.default.createDirectory(at: h.url("A"), withIntermediateDirectories: true); return h.url("A/a.txt") }())
    try Data("velho".utf8).write(to: h.url("B/a.txt"))
    h.operations.copy([h.url("A/a.txt")])
    h.prompter.answers = [1]
    _ = await h.operations.paste(into: h.url("B"))
    #expect(h.prompter.asked.map(\.title) == ["Substituir arquivo"])
    #expect(String(decoding: try Data(contentsOf: h.url("B/a.txt")), as: UTF8.self) == "velho")
}

@MainActor @Test func failuresAreShownOnce() async throws {
    let h = try OperationsHarness(["B"])
    h.pasteboard.clearContents()
    h.pasteboard.writeObjects([h.url("A/sumiu.txt") as NSURL])
    _ = await h.operations.paste(into: h.url("B"))
    #expect(h.prompter.asked.count == 1)
    #expect(h.prompter.asked.first?.title == "Erro ao copiar")
    #expect(h.prompter.asked.first?.message.contains("sumiu.txt") == true)
}

@MainActor @Test func longOperationsShowAProgressDialog() async throws {
    let h = try OperationsHarness((0..<300).map { "A/Pasta/f\($0).txt" } + ["B"], progressDelay: 0)
    h.operations.copy([h.url("A/Pasta")])
    _ = await h.operations.paste(into: h.url("B"))
    #expect(h.operations.progressDialogsShown == 1)
    #expect(h.operations.visibleProgressDialogs == 0)
    #expect(h.exists("B/Pasta/f299.txt"))
}

// MARK: Rename

@MainActor @Test func renameAsksBeforeChangingTheExtension() async throws {
    let h = try OperationsHarness(["A/a.txt"])
    let entry = try #require(try FolderListing.entries(of: h.url("A"), showHidden: false).first)
    h.prompter.answers = [1]
    #expect(await h.operations.rename(entry, to: "a.md") == nil)
    #expect(h.exists("A/a.txt"))
    #expect(h.prompter.asked == [Prompts.extensionChange(from: ".txt", to: ".md", languages: pt)])
    h.prompter.answers = [0]
    let renamed = await h.operations.rename(entry, to: "a.md")
    #expect(renamed?.path == h.url("A/a.md").path)
    #expect(h.exists("A/a.md"))
}

/// Quitting while files are being copied cancels them and waits for the cleanup: nothing half-written stays.
@MainActor @Test func cancellingRunningOperationsWaitsForThem() async throws {
    let h = try OperationsHarness((0..<50).map { "A/Pasta/f\($0).txt" } + ["B/Pasta/importante.txt"])
    h.operations.copy([h.url("A/Pasta")])
    h.prompter.answers = [0]
    var runningWhenAsked = 0
    h.prompter.onAsk = { _ in
        runningWhenAsked = h.operations.runningOperations
        h.operations.cancelRunning()
    }
    let paste = Task { await h.operations.paste(into: h.url("B")) }
    while h.operations.runningOperations == 0 { await Task.yield() }
    await h.operations.waitForOperations()
    #expect(runningWhenAsked == 1)
    #expect(h.operations.runningOperations == 0)
    #expect(h.exists("B/Pasta/importante.txt"))
    #expect(!h.exists("B/Pasta/f0.txt"))
    _ = await paste.value
}
