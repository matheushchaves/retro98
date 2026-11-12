import Foundation
import Testing
@testable import Retro98FilesCore

private let pt = ["pt-BR"]

private func write(_ url: URL, bytes: Int, modified: Date? = nil) throws {
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try Data(repeating: 65, count: bytes).write(to: url)
    if let modified { try FileManager.default.setAttributes([.modificationDate: modified], ofItemAtPath: url.path) }
}

private func entry(_ path: String, _ kind: FileKind, size: Int64? = nil) -> FileEntry {
    FileEntry(url: URL(filePath: path), name: (path as NSString).lastPathComponent, kind: kind, size: size, modified: nil, location: nil)
}

@Test func sortsFoldersFirstThenByKey() throws {
    let tree = try TempTree(["Z"])
    let d1 = Date(timeIntervalSince1970: 1_000_000), d2 = d1.addingTimeInterval(60), d3 = d2.addingTimeInterval(60)
    try write(tree.url("o.txt"), bytes: 30, modified: d1)
    try write(tree.url("a.md"), bytes: 10, modified: d3)
    try write(tree.url("b.txt"), bytes: 20, modified: d2)
    let entries = try FolderListing.entries(of: tree.root, showHidden: false)
    func names(_ key: SortKey, _ ascending: Bool) -> [String] {
        FileSorting.sorted(entries, by: SortOrder(key: key, ascending: ascending), languages: pt).map(\.name)
    }
    #expect(names(.name, true) == ["Z", "a.md", "b.txt", "o.txt"])
    #expect(names(.size, true) == ["Z", "a.md", "b.txt", "o.txt"])
    #expect(names(.size, false) == ["Z", "o.txt", "b.txt", "a.md"])
    #expect(names(.modified, true) == ["Z", "o.txt", "b.txt", "a.md"])
}

/// Type names of known extensions depend on the macOS language; unknown ones are ours ("Arquivo QQA").
@Test func sortsByTypeNameThenByName() throws {
    let tree = try TempTree(["Pasta"])
    for name in ["x.qqb", "z.qqa", "y.qqa"] { try write(tree.url(name), bytes: 1) }
    let entries = try FolderListing.entries(of: tree.root, showHidden: false)
    let sorted = FileSorting.sorted(entries, by: SortOrder(key: .type, ascending: true), languages: pt)
    #expect(sorted.map(\.name) == ["Pasta", "y.qqa", "z.qqa", "x.qqb"])
    let reversed = FileSorting.sorted(entries, by: SortOrder(key: .type, ascending: false), languages: pt)
    #expect(reversed.map(\.name) == ["Pasta", "x.qqb", "y.qqa", "z.qqa"])
}

@Test func desktopPlacesStayFirst() throws {
    let tree = try TempTree(["Desktop/zz.txt", "Desktop/aa.txt", "Documents", ".Trash"])
    let entries = DesktopLocation.entries(desktop: tree.url("Desktop"), documents: tree.url("Documents"), trash: tree.url(".Trash"),
                                          languages: pt)
    for key in SortKey.allCases {
        for ascending in [true, false] {
            let kinds = FileSorting.sorted(entries, by: SortOrder(key: key, ascending: ascending), languages: pt).prefix(3).map(\.kind)
            #expect(kinds == [.myComputer, .myDocuments, .recycleBin(isFull: false)])
        }
    }
}

@Test func typeNames() {
    func name(_ entry: FileEntry, _ languages: [String] = pt) -> String { FileTypeName.name(for: entry, languages: languages) }
    #expect(name(entry("/T/Fotos", .folder)) == "Pasta de arquivos")
    #expect(name(entry("/T/Calc.app", .application)) == "Aplicativo")
    #expect(name(entry("/Volumes/PEN", .volume(.removable))) == "Disco removível")
    #expect(name(entry("/", .volume(.internal))) == "Disco local")
    #expect(name(entry("/Volumes/Rede", .volume(.network))) == "Unidade de rede")
    #expect(name(entry("/", .myComputer)) == "Pasta do sistema")
    #expect(name(entry("/T/x.zzq", .document)) == "Arquivo ZZQ")
    #expect(name(entry("/T/LEIAME", .document)) == "Arquivo")
    #expect(!name(entry("/T/a.txt", .text)).isEmpty)
    #expect(name(entry("/T/Fotos", .folder), ["en"]) == "File Folder")
    #expect(name(entry("/T/x.zzq", .document), ["en"]) == "ZZQ File")
}

@Test func hiddenFilesAreFlagged() throws {
    let tree = try TempTree([".oculto.txt", "normal.txt", "marcado.txt"])
    var values = URLResourceValues()
    values.isHidden = true
    var marked = tree.url("marcado.txt")
    try marked.setResourceValues(values)
    let entries = try FolderListing.entries(of: tree.root, showHidden: true)
    func hidden(_ name: String) -> Bool? { entries.first { $0.name == name }?.isHidden }
    #expect(hidden(".oculto.txt") == true)
    #expect(hidden("marcado.txt") == true)
    #expect(hidden("normal.txt") == false)
}

@Test func preferencesRemember() {
    let preferences = ExplorerPreferences.memory()
    #expect(preferences.viewMode == .largeIcons)
    #expect(preferences.sort == .byName)
    #expect(preferences.showHidden == false)
    preferences.viewMode = .details
    preferences.sort = SortOrder(key: .modified, ascending: false)
    preferences.showHidden = true
    #expect(preferences.viewMode == .details)
    #expect(preferences.sort == SortOrder(key: .modified, ascending: false))
    #expect(preferences.showHidden)
    #expect(ExplorerPreferences.memory(showHidden: true).showHidden)
}

@MainActor @Test func modelSortsAndTogglesHidden() throws {
    let tree = try TempTree([".oculto.txt", ".Trash"])
    try write(tree.url("grande.txt"), bytes: 30)
    try write(tree.url("pequeno.txt"), bytes: 10)
    let environment = ExplorerEnvironment(home: tree.root, languages: pt, showHidden: false, volumes: { [] }, trash: tree.url(".Trash"))
    let model = ExplorerModel(start: .folder(tree.root), environment: environment)
    #expect(model.entries.map(\.name) == ["grande.txt", "pequeno.txt"])
    model.setSort(SortOrder(key: .size, ascending: true))
    #expect(model.entries.map(\.name) == ["pequeno.txt", "grande.txt"])
    #expect(environment.preferences.sort == SortOrder(key: .size, ascending: true))
    model.setShowHidden(true)
    #expect(model.entries.contains { $0.name == ".oculto.txt" })
    let again = ExplorerModel(start: .folder(tree.root), environment: environment)
    #expect(again.sort == SortOrder(key: .size, ascending: true))
    #expect(again.showHidden)
    #expect(again.entries.contains { $0.name == ".oculto.txt" })
}

@MainActor @Test func applyPreferencesFollowsAnotherWindow() throws {
    let tree = try TempTree([".oculto.txt", "a.txt", ".Trash"])
    let environment = ExplorerEnvironment(home: tree.root, languages: pt, showHidden: false, volumes: { [] }, trash: tree.url(".Trash"))
    let model = ExplorerModel(start: .folder(tree.root), environment: environment)
    environment.preferences.showHidden = true
    model.applyPreferences()
    #expect(model.showHidden)
    #expect(model.entries.contains { $0.name == ".oculto.txt" })
}

@Test func sortingTenThousandByTypeIsQuick() {
    let entries = (0..<10_000).map { entry("/T/f\($0).ext\($0 % 20)", .document, size: Int64($0)) }
    let start = Date()
    let sorted = FileSorting.sorted(entries, by: SortOrder(key: .type, ascending: true), languages: pt)
    #expect(Date().timeIntervalSince(start) < 1)
    #expect(sorted.count == 10_000)
}

@MainActor @Test func desktopShowsHiddenFilesWhenAsked() throws {
    let tree = try TempTree(["Desktop/.oculto.txt", "Desktop/normal.txt", ".Trash"])
    let environment = ExplorerEnvironment(home: tree.root, languages: pt, showHidden: false, volumes: { [] }, trash: tree.url(".Trash"))
    let model = ExplorerModel(start: .desktop, environment: environment)
    #expect(!model.entries.contains { $0.name == ".oculto.txt" })
    model.setShowHidden(true)
    #expect(model.entries.contains { $0.name == ".oculto.txt" })
}
