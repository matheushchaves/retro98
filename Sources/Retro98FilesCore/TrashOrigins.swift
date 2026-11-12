import Foundation

/// Where each item the Explorer sent to the Trash came from, so "Restore" can put it back
/// (macOS has no public API for the Finder's own "Put Back" records).
@MainActor
public final class TrashOrigins {
    private struct Record: Codable {
        let trashed: String
        let original: String
    }

    private let file: URL
    private let trash: URL
    /// Trashed path → original path.
    private var records: [String: String] = [:]

    /// A missing or unreadable file starts empty; records whose item already left the Trash are dropped
    /// (a Trash that can't be read, without Full Disk Access, keeps them).
    public init(file: URL, trash: URL) {
        self.file = file
        self.trash = trash
        if let data = try? Data(contentsOf: file), let saved = try? JSONDecoder().decode([Record].self, from: data) {
            for record in saved where !FileOperations.isGone(URL(filePath: record.trashed)) {
                records[record.trashed] = record.original
            }
            if records.count != saved.count { save() }
        }
    }

    /// nil when unknown, or when the item is no longer in the Trash (emptied, restored, moved).
    public func origin(of trashed: URL) -> URL? {
        let key = Self.key(trashed)
        guard let original = records[key] else { return nil }
        guard !FileOperations.isGone(trashed) else {
            records[key] = nil
            save()
            return nil
        }
        return URL(filePath: original)
    }

    /// Items sent to the Trash, or moved back into it by a redo, are remembered at once.
    public func record(_ changes: [FileChange]) {
        var changed = false
        for change in changes {
            switch change {
            case .trashed(let original, let trashed):
                records[Self.key(trashed)] = Self.key(original)
                changed = true
            case .moved(let from, let to) where isInATrash(to):
                records[Self.key(to)] = Self.key(from)
                changed = true
            default:
                break
            }
        }
        if changed { save() }
    }

    private func isInATrash(_ url: URL) -> Bool {
        let path = Self.key(url)
        return path.hasPrefix(Self.key(trash) + "/") || url.standardizedFileURL.pathComponents.contains(".Trashes")
    }

    private static func key(_ url: URL) -> String { url.standardizedFileURL.path }

    /// Best effort: if the file can't be written, "Restore" just won't know these items after a relaunch.
    private func save() {
        let saved = records.map { Record(trashed: $0.key, original: $0.value) }.sorted { $0.trashed < $1.trashed }
        guard let data = try? JSONEncoder().encode(saved) else { return }
        try? FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: file, options: .atomic)
    }
}
