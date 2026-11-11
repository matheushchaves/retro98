import Foundation

/// Loads and saves the backup as an XML property list.
public struct BackupFile {
    private struct VersionProbe: Decodable {
        let version: Int
    }

    public let url: URL
    private let files: FileStore

    public init(url: URL, files: FileStore) {
        self.url = url
        self.files = files
    }

    /// A missing file is an empty backup. An unreadable file throws and is never modified.
    public func load() throws -> Backup {
        guard let data = try files.read(url) else { return .empty }
        let decoder = PropertyListDecoder()
        do {
            let probe = try decoder.decode(VersionProbe.self, from: data)
            guard probe.version <= Backup.currentVersion else { throw BackupError.unsupportedVersion(probe.version) }
            return try decoder.decode(Backup.self, from: data)
        } catch let error as BackupError {
            throw error
        } catch {
            throw BackupError.corrupted(String(describing: error))
        }
    }

    /// Saving an empty backup deletes the file.
    public func save(_ backup: Backup) throws {
        guard !backup.isEmpty else {
            try files.write(nil, to: url)
            return
        }
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .xml
        try files.write(try encoder.encode(backup), to: url)
    }
}
