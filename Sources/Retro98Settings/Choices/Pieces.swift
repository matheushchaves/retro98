import Foundation

/// The installer's `pieces` file: one line of words such as "base shell prompt". The Control Panel edits it
/// so `./install.sh --yes` keeps what was turned on or off there ("shelloff" = taskbar installed but off).
public struct Pieces: Equatable, Sendable {
    public let words: [String]

    public init(line: String) {
        words = line.split(whereSeparator: \.isWhitespace).map(String.init)
    }

    private init(words: [String]) {
        self.words = words
    }

    public var line: String { words.joined(separator: " ") }

    public func contains(_ piece: String) -> Bool { words.contains(piece) }

    public func adding(_ piece: String) -> Pieces {
        contains(piece) ? self : Pieces(words: words + [piece])
    }

    public func removing(_ piece: String) -> Pieces {
        Pieces(words: words.filter { $0 != piece })
    }

    /// Swaps `old` for `new` in place; without `old`, adds `new` at the end (never twice).
    public func replacing(_ old: String, with new: String) -> Pieces {
        guard contains(old) else { return adding(new) }
        var seen = false
        return Pieces(words: words.compactMap { word in
            let replaced = word == old ? new : word
            if replaced == new {
                defer { seen = true }
                return seen ? nil : replaced
            }
            return replaced
        })
    }
}

public struct PiecesFile {
    private let url: URL
    private let files: FileStore

    public init(url: URL, files: FileStore) {
        self.url = url
        self.files = files
    }

    /// A missing or unreadable file is an empty line.
    public func load() -> Pieces {
        guard let data = try? files.read(url) else { return Pieces(line: "") }
        return Pieces(line: String(decoding: data, as: UTF8.self))
    }

    public func save(_ pieces: Pieces) throws {
        try files.write(Data((pieces.line + "\n").utf8), to: url)
    }
}
