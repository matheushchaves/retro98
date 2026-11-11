import Foundation
import Testing
@testable import Retro98FilesCore

@MainActor private func environment(_ home: TempTree) -> ExplorerEnvironment {
    ExplorerEnvironment(home: home.root, languages: ["pt-BR"], showHidden: false,
                        volumes: { [VolumeInfo(url: URL(filePath: "/"), name: "Macintosh HD", kind: .internal,
                                               totalBytes: 1000, freeBytes: 500, isEjectable: false)] },
                        trash: home.root.appending(path: ".Trash"))
}

@MainActor @Test func startsOnTheDesktop() throws {
    let home = try TempTree(["Desktop/nota.txt", "Documents", ".Trash"])
    let model = ExplorerModel(start: .desktop, environment: environment(home))
    #expect(model.title == "Área de Trabalho")
    #expect(model.entries.prefix(3).map(\.kind) == [.myComputer, .myDocuments, .recycleBin(isFull: false)])
    #expect(model.entries.last?.name == "nota.txt")
}

@MainActor @Test func openingAFolderNavigatesAndAFileReturnsItsURL() throws {
    let home = try TempTree(["Desktop/Pasta/dentro.txt", ".Trash"])
    let model = ExplorerModel(start: .desktop, environment: environment(home))
    let folder = try #require(model.entries.first { $0.name == "Pasta" })
    #expect(model.open(folder) == nil)
    #expect(model.history.current == folder.location)
    let file = try #require(model.entries.first { $0.name == "dentro.txt" })
    #expect(model.open(file) == file.url)
}

@MainActor @Test func myComputerListsVolumes() throws {
    let home = try TempTree([".Trash"])
    let model = ExplorerModel(start: .myComputer, environment: environment(home))
    #expect(model.entries.map(\.name) == ["Macintosh HD"])
    #expect(model.entries.first?.kind == .volume(.internal))
    #expect(model.entries.first?.location == .folder(URL(filePath: "/")))
}

@MainActor @Test func upAndHistory() throws {
    let home = try TempTree(["A/B", ".Trash"])
    let model = ExplorerModel(start: .folder(home.root.appending(path: "A/B", directoryHint: .notDirectory)), environment: environment(home))
    model.up()
    #expect(model.history.current == .folder(home.root.appending(path: "A", directoryHint: .notDirectory)))
    model.back()
    #expect(model.history.current == .folder(home.root.appending(path: "A/B", directoryHint: .notDirectory)))
    model.forward()
    #expect(model.history.current == .folder(home.root.appending(path: "A", directoryHint: .notDirectory)))
}

@MainActor @Test func vanishedFolderRecovers() throws {
    let home = try TempTree(["A/B", ".Trash"])
    let b = home.root.appending(path: "A/B", directoryHint: .notDirectory)
    let model = ExplorerModel(start: .folder(b), environment: environment(home))
    try FileManager.default.removeItem(at: b)
    model.reload()
    #expect(model.history.current == .folder(home.root.appending(path: "A", directoryHint: .notDirectory)))
}

@MainActor @Test func permissionErrorIsShownNotThrown() throws {
    let home = try TempTree(["Trancada/x.txt", ".Trash"])
    let locked = home.root.appending(path: "Trancada", directoryHint: .notDirectory)
    try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: locked.path)
    defer { try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: locked.path) }
    let model = ExplorerModel(start: .folder(locked), environment: environment(home))
    #expect(model.error == ExplorerText.permissionDenied(["pt-BR"]))
    #expect(model.entries.isEmpty)
}

@MainActor @Test func unreadableTrashExplainsAndOffersFinder() throws {
    let home = try TempTree([])
    let model = ExplorerModel(start: .trash, environment: environment(home))   // .Trash doesn't exist → unreadable
    #expect(model.error == ExplorerText.trashNeedsAccess(["pt-BR"]))
}

private final class CallCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0
    var value: Int { lock.withLock { count } }
    func increment() { lock.withLock { count += 1 } }
}

/// Listing volumes can block on a stale network mount: read them once per load, not per click.
@MainActor @Test func volumesAreReadOncePerLoad() throws {
    let home = try TempTree(["Desktop/a.txt", ".Trash"])
    let calls = CallCounter()
    let environment = ExplorerEnvironment(home: home.root, languages: ["pt-BR"], showHidden: false, volumes: {
        calls.increment()
        return [VolumeInfo(url: URL(filePath: "/"), name: "Macintosh HD", kind: .internal, totalBytes: 1000, freeBytes: 500, isEjectable: false)]
    }, trash: home.root.appending(path: ".Trash"))
    let model = ExplorerModel(start: .desktop, environment: environment)
    #expect(model.freeSpace == 500)
    #expect(calls.value == 1)
    model.reload()
    #expect(calls.value == 2)
}
