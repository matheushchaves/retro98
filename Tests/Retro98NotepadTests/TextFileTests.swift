import Foundation
import Testing
@testable import Retro98Notepad

private func utf8(_ text: String) -> Data { Data(text.utf8) }

@Test func decodeUsesTheFilesLineEnding() throws {
    let windows = try TextFile.decode(utf8("a\r\nb\r\n"))
    #expect(windows.text == "a\nb\n")
    #expect(windows.lineEnding == .crlf)
    #expect(try TextFile.decode(utf8("a\rb")).lineEnding == .cr)
    #expect(try TextFile.decode(utf8("a")).lineEnding == .lf)
}

@Test func decodeTakesTheMostCommonEnding() throws {
    let file = try TextFile.decode(utf8("a\r\nb\nc\nd"))
    #expect(file.lineEnding == .lf)
    #expect(file.text == "a\nb\nc\nd")
}

@Test func decodeTieGoesToTheFirstEnding() throws {
    #expect(try TextFile.decode(utf8("a\rb\nc")).lineEnding == .cr)
}

@Test func decodeKeepsTheBOM() throws {
    let data = Data([0xEF, 0xBB, 0xBF]) + utf8("oi")
    let file = try TextFile.decode(data)
    #expect(file.text == "oi")
    #expect(file.hasBOM)
    #expect(file.encoded() == data)
}

@Test(arguments: ["a\r\nb\r\n", "a\nb", "a\rb\r", "\u{FEFF}ação\r\n", ""])
func roundTripIsExact(text: String) throws {
    let data = utf8(text)
    #expect(try TextFile.decode(data).encoded() == data)
}

@Test func decodeRefusesNonUTF8() {
    #expect(throws: TextFileError.notUTF8) { try TextFile.decode(Data([0x61, 0xE7, 0x61])) }
}

@Test func decodeRefusesBinary() {
    #expect(throws: TextFileError.notText) { try TextFile.decode(utf8("a\u{0}b")) }
}

@Test func encodedNormalizesPastedBreaks() {
    let file = TextFile(text: "a\r\nb\rc\n", lineEnding: .crlf, hasBOM: false)
    #expect(file.encoded() == utf8("a\r\nb\r\nc\r\n"))
}

@Test func readRefusesFilesOverTheLimit() throws {
    let root = try temporaryFolder()
    defer { try? FileManager.default.removeItem(at: root) }
    for (name, size, error) in [("grande.txt", TextFile.maximumSize + 1, TextFileError.tooLarge),
                                ("limite.txt", TextFile.maximumSize, TextFileError.notText)] {
        let url = root.appending(path: name)
        try Data().write(to: url)
        let handle = try FileHandle(forWritingTo: url)
        try handle.truncate(atOffset: UInt64(size))
        try handle.close()
        #expect(throws: error) { try TextFile.read(from: url) }
    }
}

@Test func readMissingFileIsUnreadable() throws {
    let root = try temporaryFolder()
    defer { try? FileManager.default.removeItem(at: root) }
    #expect(throws: TextFileError.unreadable) { try TextFile.read(from: root.appending(path: "nada.txt")) }
}

@Test func writeKeepsPermissions() throws {
    let root = try temporaryFolder()
    defer { try? FileManager.default.removeItem(at: root) }
    let url = root.appending(path: "segredo.txt")
    try utf8("antes").write(to: url)
    try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)

    try TextFile(text: "depois", lineEnding: .lf, hasBOM: false).write(to: url)

    #expect(try Data(contentsOf: url) == utf8("depois"))
    #expect(try FileManager.default.attributesOfItem(atPath: url.path)[.posixPermissions] as? Int == 0o600)
}

@Test func writeThroughSymlinkKeepsTheLink() throws {
    let root = try temporaryFolder()
    defer { try? FileManager.default.removeItem(at: root) }
    let real = root.appending(path: "real.txt"), link = root.appending(path: "link.txt")
    try utf8("antes").write(to: real)
    try FileManager.default.createSymbolicLink(at: link, withDestinationURL: real)
    let destination = try FileManager.default.destinationOfSymbolicLink(atPath: link.path)

    try TextFile(text: "depois", lineEnding: .lf, hasBOM: false).write(to: link)

    #expect(try FileManager.default.destinationOfSymbolicLink(atPath: link.path) == destination)
    #expect(try Data(contentsOf: real) == utf8("depois"))
}

@Test func writeCreatesNewFile() throws {
    let root = try temporaryFolder()
    defer { try? FileManager.default.removeItem(at: root) }
    let url = root.appending(path: "novo.txt")
    try TextFile(text: "a\nb", lineEnding: .crlf, hasBOM: false).write(to: url)
    #expect(try Data(contentsOf: url) == utf8("a\r\nb"))
}

@Test func failedWriteLeavesTheOriginal() throws {
    let root = try temporaryFolder()
    defer {
        try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: root.path)
        try? FileManager.default.removeItem(at: root)
    }
    let url = root.appending(path: "fixo.txt")
    try utf8("original").write(to: url)
    try FileManager.default.setAttributes([.posixPermissions: 0o500], ofItemAtPath: root.path)

    #expect(throws: (any Error).self) { try TextFile(text: "novo", lineEnding: .lf, hasBOM: false).write(to: url) }
    #expect(try Data(contentsOf: url) == utf8("original"))
}

@Test func readRefusesABigFileBehindALink() throws {
    let root = try temporaryFolder()
    defer { try? FileManager.default.removeItem(at: root) }
    let big = root.appending(path: "grande.log"), link = root.appending(path: "atalho.log")
    try Data().write(to: big)
    let handle = try FileHandle(forWritingTo: big)
    try handle.truncate(atOffset: UInt64(TextFile.maximumSize + 1))
    try handle.close()
    try FileManager.default.createSymbolicLink(at: link, withDestinationURL: big)
    #expect(throws: TextFileError.tooLarge) { try TextFile.read(from: link) }
}

@Test func writeNeverReplacesAFolder() throws {
    let root = try temporaryFolder()
    defer { try? FileManager.default.removeItem(at: root) }
    let folder = root.appending(path: "virou-pasta.txt")
    try FileManager.default.createDirectory(at: folder.appending(path: "dentro"), withIntermediateDirectories: true)
    try Data("guardado".utf8).write(to: folder.appending(path: "dentro/a.txt"))

    #expect(throws: (any Error).self) { try TextFile(text: "novo", lineEnding: .lf, hasBOM: false).write(to: folder) }
    #expect(try Data(contentsOf: folder.appending(path: "dentro/a.txt")) == Data("guardado".utf8))
}
