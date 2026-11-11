import Foundation
import Testing
@testable import Retro98FilesCore

@Test func listsFoldersFirstThenNames() throws {
    let tree = try TempTree(["b.txt", "A.txt", "Pasta", "zeta"])
    let names = try FolderListing.entries(of: tree.root, showHidden: false).map(\.name)
    #expect(names == ["Pasta", "zeta", "A.txt", "b.txt"])
}

@Test func hiddenFilesStayHiddenUnlessAsked() throws {
    let tree = try TempTree([".oculto.txt", "visivel.txt"])
    #expect(try FolderListing.entries(of: tree.root, showHidden: false).map(\.name) == ["visivel.txt"])
    #expect(try FolderListing.entries(of: tree.root, showHidden: true).count == 2)
}

@Test func packagesAreNotFolders() throws {
    let tree = try TempTree(["Foo.app/Contents", "Lib.bundle/Contents", "Real"])
    let entries = try FolderListing.entries(of: tree.root, showHidden: false)
    let byName = Dictionary(uniqueKeysWithValues: entries.map { ($0.name, $0) })
    #expect(byName["Foo"]?.kind == .application)
    #expect(byName["Foo"]?.location == nil)
    #expect(byName["Real"]?.kind == .folder)
    #expect(byName["Real"]?.location == .folder(tree.root.appending(path: "Real", directoryHint: .notDirectory)))
    #expect(byName["Lib.bundle"].map { $0.kind != .folder && $0.location == nil } == true)
}

@Test func classifiesByType() {
    let check = { (name: String) in FileKindClassifier.kind(for: URL(filePath: "/tmp/\(name)"), isDirectory: false, isPackage: false) }
    #expect(check("a.png") == .image)
    #expect(check("a.mp3") == .audio)
    #expect(check("a.mov") == .video)
    #expect(check("a.zip") == .archive)
    #expect(check("a.txt") == .text)
    #expect(check("a.swift") == .text)
    #expect(check("a.pdf") == .document)
    #expect(check("semextensao") == .document)
}

@Test func listsTenThousandFilesQuickly() throws {
    let root = FileManager.default.temporaryDirectory.appending(path: "retro98-big-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    for index in 0..<10_000 { FileManager.default.createFile(atPath: root.appending(path: "f\(index).txt").path, contents: nil) }
    let start = Date()
    let entries = try FolderListing.entries(of: root, showHidden: false)
    #expect(entries.count == 10_000)
    #expect(Date().timeIntervalSince(start) < 1.0)
}

@Test func unreadableFolderReportsPermission() throws {
    let tree = try TempTree(["Trancada/x.txt"])
    let locked = tree.root.appending(path: "Trancada")
    try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: locked.path)
    defer { try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: locked.path) }
    #expect(throws: FolderListingError.permissionDenied) { try FolderListing.entries(of: locked, showHidden: false) }
    #expect(throws: FolderListingError.notFound) { try FolderListing.entries(of: tree.root.appending(path: "nada"), showHidden: false) }
}

@Test func desktopShowsFixedItemsThenFiles() throws {
    let home = try TempTree(["Desktop/b.txt", "Desktop/A.txt", "Documents", ".Trash"])
    let entries = DesktopLocation.entries(desktop: home.root.appending(path: "Desktop"), documents: home.root.appending(path: "Documents"),
                                          trash: home.root.appending(path: ".Trash"), languages: ["pt-BR"])
    #expect(entries.prefix(3).map(\.name) == ["Meu Computador", "Meus Documentos", "Lixeira"])
    #expect(entries.prefix(3).map(\.location) == [.myComputer, .folder(home.root.appending(path: "Documents")), .trash])
    #expect(entries.dropFirst(3).map(\.name) == ["A.txt", "b.txt"])
    let unreadable = DesktopLocation.entries(desktop: home.root.appending(path: "nao-existe"), documents: home.root,
                                             trash: home.root, languages: ["en"])
    #expect(unreadable.map(\.name) == ["My Computer", "My Documents", "Recycle Bin"])
}

@Test func watcherFiresOnChange() async throws {
    let tree = try TempTree(["x"])
    try await confirmation(expectedCount: 1...) { fired in
        let watcher = DirectoryWatcher(url: tree.root) { fired() }
        #expect(watcher != nil)
        try Data().write(to: tree.root.appending(path: "novo.txt"))
        try await Task.sleep(for: .milliseconds(500))
        watcher?.stop()
    }
}
