import Foundation
import Testing
@testable import Retro98Settings

@Test func piecesKeepOrderAndSpacing() {
    let pieces = Pieces(line: " base  shell prompt\n")
    #expect(pieces.line == "base shell prompt")
    #expect(pieces.contains("shell"))
    #expect(!pieces.contains("shelloff"))
    #expect(pieces.replacing("shell", with: "shelloff").line == "base shelloff prompt")
    #expect(pieces.adding("fileviewer").adding("fileviewer").line == "base shell prompt fileviewer")
    #expect(pieces.adding("fileviewer").removing("fileviewer") == pieces)
    #expect(Pieces(line: "base prompt").replacing("shelloff", with: "shell").line == "base prompt shell")
    #expect(Pieces(line: "base shell").replacing("shelloff", with: "shell").line == "base shell")
}

@Test func piecesFileRoundTrip() throws {
    let url = URL(filePath: "/home/Library/Application Support/Retro98/pieces")
    let files = InMemoryFileStore()
    let file = PiecesFile(url: url, files: files)
    #expect(file.load().line == "")
    try file.save(Pieces(line: "base shell"))
    #expect(try files.read(url) == Data("base shell\n".utf8))
    #expect(file.load() == Pieces(line: "base shell"))
}
