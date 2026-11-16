import Foundation
import Testing
@testable import Retro98Browser

@Test func cleanNames() {
    #expect(DownloadNames.clean("a/b/c.zip") == "c.zip")
    #expect(DownloadNames.clean("..\u{0}evil") == "evil")
    #expect(DownloadNames.clean("a:b.txt") == "a-b.txt")
    #expect(DownloadNames.clean("") == "download")
    #expect(DownloadNames.clean("...") == "download")
    #expect(DownloadNames.clean("..\\..\\win.ini") == "win.ini")
}

private func touch(_ name: String, in folder: URL, _ text: String = "") throws {
    try Data(text.utf8).write(to: folder.appending(path: name))
}

@Test func freeNames() throws {
    let folder = try temporaryFolder()
    defer { try? FileManager.default.removeItem(at: folder) }
    #expect(DownloadNames.free("a.txt", in: folder) == "a.txt")
    try touch("a.txt", in: folder)
    #expect(DownloadNames.free("a.txt", in: folder) == "a (2).txt")
    try touch("a (2).txt", in: folder)
    #expect(DownloadNames.free("a.txt", in: folder) == "a (3).txt")
    try touch("b.txt.download", in: folder)
    #expect(DownloadNames.free("b.txt", in: folder) == "b (2).txt")
    try touch("arquivo", in: folder)
    #expect(DownloadNames.free("arquivo", in: folder) == "arquivo (2)")
}

@Test func finishMovesToTheFinalName() throws {
    let folder = try temporaryFolder()
    defer { try? FileManager.default.removeItem(at: folder) }
    let file = DownloadFile(suggestedName: "a.txt", folder: folder)
    #expect(file.partURL == folder.appending(path: "a.txt.download"))
    try Data("oi".utf8).write(to: file.partURL)
    let final = try file.finish()
    #expect(final == folder.appending(path: "a.txt"))
    #expect(try String(contentsOf: final, encoding: .utf8) == "oi")
    #expect(!FileManager.default.fileExists(atPath: file.partURL.path))
}

@Test func finishNeverReplaces() throws {
    let folder = try temporaryFolder()
    defer { try? FileManager.default.removeItem(at: folder) }
    let file = DownloadFile(suggestedName: "a.txt", folder: folder)
    try Data("novo".utf8).write(to: file.partURL)
    try touch("a.txt", in: folder, "antigo")
    let final = try file.finish()
    #expect(final.lastPathComponent == "a (2).txt")
    #expect(try String(contentsOf: folder.appending(path: "a.txt"), encoding: .utf8) == "antigo")
    #expect(try String(contentsOf: final, encoding: .utf8) == "novo")
}

@Test func finishWithoutAPartFails() throws {
    let folder = try temporaryFolder()
    defer { try? FileManager.default.removeItem(at: folder) }
    #expect(throws: (any Error).self) { try DownloadFile(suggestedName: "a.txt", folder: folder).finish() }
}

@Test func discardRemovesThePart() throws {
    let folder = try temporaryFolder()
    defer { try? FileManager.default.removeItem(at: folder) }
    let file = DownloadFile(suggestedName: "a.txt", folder: folder)
    try Data("meio".utf8).write(to: file.partURL)
    file.discard()
    #expect(try FileManager.default.contentsOfDirectory(atPath: folder.path).isEmpty)
}

@Test func discardWithoutAPartIsQuiet() throws {
    let folder = try temporaryFolder()
    defer { try? FileManager.default.removeItem(at: folder) }
    DownloadFile(suggestedName: "a.txt", folder: folder).discard()
}

@Test func twoDownloadsOfTheSameNameGetDifferentParts() throws {
    let folder = try temporaryFolder()
    defer { try? FileManager.default.removeItem(at: folder) }
    let first = DownloadFile(suggestedName: "a.txt", folder: folder)
    // WebKit creates the file later, so the first part isn't on disk yet: the names in flight are passed along.
    let second = DownloadFile(suggestedName: "a.txt", folder: folder, inFlight: [first.partURL.lastPathComponent])
    #expect(second.partURL.lastPathComponent == "a (2).txt.download")
    try Data("1".utf8).write(to: first.partURL)
    try Data("2".utf8).write(to: second.partURL)
    #expect(try first.finish().lastPathComponent == "a.txt")
    #expect(try second.finish().lastPathComponent == "a (2).txt")
}
