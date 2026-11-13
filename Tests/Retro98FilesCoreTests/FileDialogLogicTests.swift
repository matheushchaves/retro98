import Foundation
import Testing
@testable import Retro98FilesCore

private let textFiles = FileTypeFilter(title: "Texto", extensions: ["txt"])
private let allFiles = FileTypeFilter(title: "Todos", extensions: [])

private func dialogTree() throws -> TempTree {
    let tree = try TempTree(["b.txt", "sub", ".hidden.txt", "App.app/Contents"])
    // TempTree only makes files for ".txt" paths.
    try Data().write(to: tree.url("A.TXT"))
    try Data().write(to: tree.url("c.md"))
    return tree
}

/// The outcome with plain paths, so the comparison doesn't depend on how each URL was built.
private func describe(_ outcome: FileDialogOutcome) -> String {
    switch outcome {
    case .nothing: "nothing"
    case .navigate(let url): "navigate \(url.path)"
    case .choose(let url): "choose \(url.path)"
    case .confirmReplace(let url): "confirmReplace \(url.path)"
    case .notFound(let text): "notFound \(text)"
    case .invalidName(let text): "invalidName \(text)"
    case .folderNotFound(let path): "folderNotFound \(path)"
    }
}

@Test func entriesFilterByTypeAndSkipHiddenAndPackages() throws {
    let tree = try dialogTree()
    #expect(try FileDialogLogic.entries(of: tree.root, filter: textFiles).map(\.name) == ["sub", "A.TXT", "b.txt"])
    #expect(try FileDialogLogic.entries(of: tree.root, filter: allFiles).map(\.name) == ["sub", "A.TXT", "b.txt", "c.md"])
}

@Test func entriesOfUnreadableFolderThrow() throws {
    let tree = try TempTree(["locked"])
    let locked = tree.url("locked")
    try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: locked.path)
    defer { try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: locked.path) }
    #expect(throws: FolderListingError.permissionDenied) { try FileDialogLogic.entries(of: locked, filter: allFiles) }
    #expect(throws: FolderListingError.notFound) { try FileDialogLogic.entries(of: tree.url("sumiu"), filter: allFiles) }
}

@Test func resolveForOpen() throws {
    let tree = try dialogTree()
    let root = tree.root.path
    func open(_ text: String) -> String {
        describe(FileDialogLogic.resolve(text, in: tree.root, mode: .open, filter: textFiles, home: tree.root))
    }
    #expect(open("b.txt") == "choose \(root)/b.txt")
    #expect(open("sub") == "navigate \(root)/sub")
    #expect(open("~") == "navigate \(root)")
    #expect(open("~/sub") == "navigate \(root)/sub")
    #expect(open("\(root)/b.txt") == "choose \(root)/b.txt")
    #expect(open("sub/../b.txt") == "choose \(root)/b.txt")
    #expect(open("  ") == "nothing")
    #expect(open("nope.txt") == "notFound nope.txt")
}

@Test func resolveForSave() throws {
    let tree = try dialogTree()
    let root = tree.root.path
    func save(_ text: String, _ filter: FileTypeFilter = textFiles) -> String {
        describe(FileDialogLogic.resolve(text, in: tree.root, mode: .save, filter: filter, home: tree.root))
    }
    #expect(save("nota") == "choose \(root)/nota.txt")
    #expect(save("nota.md") == "choose \(root)/nota.md")
    #expect(save("nota", allFiles) == "choose \(root)/nota")
    #expect(save("b") == "confirmReplace \(root)/b.txt")
    #expect(save("a:b") == "invalidName a:b")
    #expect(save("missing/x.txt") == "folderNotFound \(root)/missing")
    #expect(save("sub") == "navigate \(root)/sub")
}

@Test func placesNestTheCurrentFolderUnderItsVolume() {
    let volumes = [
        VolumeInfo(url: URL(filePath: "/"), name: "Macintosh HD", kind: .internal, totalBytes: nil, freeBytes: nil, isEjectable: false),
        VolumeInfo(url: URL(filePath: "/Volumes/PEN"), name: "PEN", kind: .removable, totalBytes: nil, freeBytes: nil, isEjectable: true),
    ]
    let places = FileDialogLogic.places(current: URL(filePath: "/Volumes/PEN/fotos/2024"), home: URL(filePath: "/Users/u"),
                                        volumes: volumes, languages: ["pt-BR"])
    #expect(places.map(\.name) == ["Área de Trabalho", "Macintosh HD", "PEN", "fotos", "2024", "Meus Documentos"])
    #expect(places.map(\.depth) == [0, 1, 1, 2, 3, 1])
    #expect(places.map(\.kind) == [.desktop, .volume(.internal), .volume(.removable), .folder, .folder, .documents])
    #expect(places.map(\.url.path) == ["/Users/u/Desktop", "/", "/Volumes/PEN", "/Volumes/PEN/fotos", "/Volumes/PEN/fotos/2024",
                                       "/Users/u/Documents"])
}

@Test func placesAtAVolumeRootHaveNoChain() {
    let volumes = [VolumeInfo(url: URL(filePath: "/Volumes/PEN"), name: "PEN", kind: .removable, totalBytes: nil, freeBytes: nil,
                              isEjectable: true)]
    let places = FileDialogLogic.places(current: URL(filePath: "/Volumes/PEN"), home: URL(filePath: "/Users/u"), volumes: volumes,
                                        languages: ["en"])
    #expect(places.map(\.name) == ["Desktop", "PEN", "My Documents"])
}

@Test func filterMatchesExtensionsWithoutCase() {
    #expect(textFiles.matches(URL(filePath: "/x/LEIA.TXT")))
    #expect(!textFiles.matches(URL(filePath: "/x/leia.md")))
    #expect(allFiles.matches(URL(filePath: "/x/qualquer")))
    #expect(textFiles.defaultExtension == "txt" && allFiles.defaultExtension == nil)
}
