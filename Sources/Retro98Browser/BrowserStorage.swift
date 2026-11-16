import Foundation

/// One JSON file in the browser's data folder.
struct BrowserStorage<Value: Codable> {
    let file: URL

    /// Where a file that can't be read is kept, so the person's list is never thrown away: "<name>-damaged.json".
    var damagedFile: URL {
        file.deletingLastPathComponent().appending(path: file.deletingPathExtension().lastPathComponent + "-damaged.json")
    }

    /// nil when there is no file, or when it can't be read as this value (it is then moved aside).
    func load(fileManager: FileManager = .default) -> Value? {
        guard fileManager.fileExists(atPath: file.path) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let data = try? Data(contentsOf: file), let value = try? decoder.decode(Value.self, from: data) { return value }
        try? fileManager.removeItem(at: damagedFile)
        try? fileManager.moveItem(at: file, to: damagedFile)
        return nil
    }

    func save(_ value: Value, fileManager: FileManager = .default) throws {
        try fileManager.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        try encoder.encode(value).write(to: file, options: .atomic)
    }
}
