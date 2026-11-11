import Foundation

public protocol FileStore {
    /// Returns nil when the file does not exist.
    func read(_ url: URL) throws -> Data?
    /// Writes atomically, creating parent folders; nil deletes the file if present.
    func write(_ data: Data?, to url: URL) throws
}

public struct LocalFileStore: FileStore {
    public init() {}

    public func read(_ url: URL) throws -> Data? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try Data(contentsOf: url)
    }

    public func write(_ data: Data?, to url: URL) throws {
        let fileManager = FileManager.default
        guard let data else {
            if fileManager.fileExists(atPath: url.path) {
                try fileManager.removeItem(at: url)
            }
            return
        }
        try fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
    }
}

public final class InMemoryFileStore: FileStore {
    private var storage: [URL: Data]

    public init(_ files: [URL: Data] = [:]) {
        self.storage = files
    }

    public var snapshot: [URL: Data] { storage }

    public func read(_ url: URL) throws -> Data? { storage[url] }

    public func write(_ data: Data?, to url: URL) throws {
        storage[url] = data
    }
}
