import Foundation
import Testing
@testable import Retro98FilesCore

private let pt = ["pt-BR"], brazil = Locale(identifier: "pt_BR")

private func write(_ url: URL, bytes: Int) throws {
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try Data(repeating: 65, count: bytes).write(to: url)
}

@Test func folderTallyCountsEverything() throws {
    let tree = try TempTree(["A/Sub2"])
    try write(tree.url("A/f1"), bytes: 10)
    try write(tree.url("A/f2"), bytes: 20)
    try write(tree.url("A/f3"), bytes: 30)
    try write(tree.url("A/Sub1/f4"), bytes: 40)
    let tally = PropertiesReader.measure(tree.url("A"), control: OperationControl(), onProgress: { _ in })
    #expect(tally == FolderTally(bytes: 100, files: 4, folders: 2, skippedUnreadable: false))
}

@Test func measureSkipsUnreadableAndSaysSo() throws {
    let tree = try TempTree([])
    try write(tree.url("A/ok"), bytes: 5)
    try write(tree.url("A/Trancada/x"), bytes: 7)
    let locked = tree.url("A/Trancada").path
    try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: locked)
    defer { try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: locked) }
    let tally = PropertiesReader.measure(tree.url("A"), control: OperationControl(), onProgress: { _ in })
    #expect(tally.skippedUnreadable)
    #expect(tally.bytes == 5 && tally.files == 1 && tally.folders == 1)
}

@Test func measureStopsWhenCancelled() throws {
    let tree = try TempTree((0..<50).map { "A/f\($0).txt" })
    let control = OperationControl()
    control.cancel()
    #expect(PropertiesReader.measure(tree.url("A"), control: control, onProgress: { _ in }).files == 0)
}

@Test func sizeAndContainsTexts() {
    #expect(PropertiesText.size(1_234_567, locale: brazil, languages: pt) == "1,2 MB (1.234.567 bytes)")
    #expect(PropertiesText.size(5, locale: brazil, languages: pt) == "5 bytes")
    #expect(PropertiesText.contains(files: 1, folders: 1, languages: pt) == "1 arquivo, 1 pasta")
    #expect(PropertiesText.contains(files: 2, folders: 3, languages: pt) == "2 arquivos, 3 pastas")
    #expect(PropertiesText.contains(files: 2, folders: 3, languages: ["en"]) == "2 files, 3 folders")
}

@Test func summaryOfOneFileAndOfSeveral() throws {
    let tree = try TempTree(["A/Pasta", "B"])
    try write(tree.url("A/a.txt"), bytes: 12)
    try write(tree.url("A/b.txt"), bytes: 8)
    try write(tree.url("B/c.txt"), bytes: 1)
    let listed = try FolderListing.entries(of: tree.url("A"), showHidden: false)
    func entry(_ name: String) throws -> FileEntry { try #require(listed.first { $0.name == name }) }
    let location = (tree.url("A").path as NSString).abbreviatingWithTildeInPath

    let one = PropertiesReader.summary(of: [try entry("a.txt")], languages: pt)
    #expect(one.title == "Propriedades de a.txt")
    #expect(one.name == "a.txt")
    #expect(one.location == location)
    #expect(one.tally == FolderTally(bytes: 12, files: 1, folders: 0, skippedUnreadable: false))
    #expect(one.needsMeasuring.isEmpty)
    #expect(one.modified != nil)

    let several = PropertiesReader.summary(of: [try entry("a.txt"), try entry("b.txt"), try entry("Pasta")], languages: pt)
    #expect(several.title == "3 itens")
    #expect(several.location == location)
    #expect(several.tally == FolderTally(bytes: 20, files: 2, folders: 1, skippedUnreadable: false))
    #expect(several.needsMeasuring.map(\.path) == [tree.url("A/Pasta").path])
    #expect(several.modified == nil && several.created == nil && several.accessed == nil)
    #expect(several.typeName == "Vários tipos")

    let other = try #require(try FolderListing.entries(of: tree.url("B"), showHidden: false).first)
    #expect(PropertiesReader.summary(of: [try entry("a.txt"), other], languages: pt).location == nil)

    let folder = PropertiesReader.summary(of: [try entry("Pasta")], languages: pt)
    #expect(folder.tally == FolderTally(bytes: 0, files: 0, folders: 0, skippedUnreadable: false))
    #expect(folder.needsMeasuring.map(\.path) == [tree.url("A/Pasta").path])
}

@Test func volumeTexts() {
    let volume = VolumeInfo(url: URL(filePath: "/Volumes/PEN"), name: "PEN", kind: .removable, totalBytes: 1000, freeBytes: 250,
                            isEjectable: true)
    let texts = PropertiesText.volume(volume, locale: brazil, languages: pt)
    #expect(texts.fraction == 0.75)
    #expect(texts.used.contains("750 bytes"))
    #expect(texts.free.contains("250 bytes"))
}

@Test func openWithPutsTheDefaultFirst() {
    let a = URL(filePath: "/Apps/A.app"), b = URL(filePath: "/Apps/B.app"), c = URL(filePath: "/Apps/C.app")
    let choices = OpenWithList.choices(defaultApp: b, apps: [c, b, a, a])
    #expect(choices.map(\.name) == ["B", "A", "C"])
    #expect(choices.map(\.isDefault) == [true, false, false])
    #expect(OpenWithList.choices(defaultApp: nil, apps: [c, a]).map(\.name) == ["A", "C"])
}

@Test func revealGroupsByFolder() throws {
    let tree = try TempTree(["X/a.txt", "Y/b.txt", "X/c.txt", "Pasta"])
    let plan = RevealPlan.windows(for: [tree.url("X/a.txt"), tree.url("Y/b.txt"), tree.url("X/c.txt")])
    #expect(plan == [RevealWindow(folder: tree.url("X"), select: [tree.url("X/a.txt"), tree.url("X/c.txt")]),
                     RevealWindow(folder: tree.url("Y"), select: [tree.url("Y/b.txt")])])
    #expect(RevealPlan.windows(for: [tree.url("Pasta")]) == [RevealWindow(folder: tree.url("Pasta"), select: [])])
}

@Test func ejectFailedPrompt() {
    let prompt = Prompts.ejectFailed(name: "PEN", reason: "Em uso.", languages: pt)
    #expect(prompt.title == "Erro ao ejetar")
    #expect(prompt.message == "Não foi possível ejetar 'PEN': Em uso.")
    #expect(prompt.buttons == ["OK"])
}

/// Apps and other packages are folders on disk: their size is measured, but they count as one item.
@Test func summaryMeasuresPackagesForSize() throws {
    let tree = try TempTree(["A/Calc.app/Contents"])
    try write(tree.url("A/Calc.app/Contents/binario"), bytes: 5000)
    let app = try #require(try FolderListing.entries(of: tree.url("A"), showHidden: false).first)
    #expect(app.kind == .application)
    let summary = PropertiesReader.summary(of: [app], languages: pt)
    #expect(summary.packages.map(\.path) == [tree.url("A/Calc.app").path])
    #expect(summary.needsMeasuring.isEmpty)
    #expect(summary.tally.files == 1)
}
