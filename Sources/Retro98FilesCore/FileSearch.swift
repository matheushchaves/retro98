import Foundation

public struct SearchQuery: Equatable, Sendable {
    public let text: String
    public let root: URL
    public let includeSubfolders: Bool
    public let showHidden: Bool

    public init(text: String, root: URL, includeSubfolders: Bool, showHidden: Bool) {
        self.text = text
        self.root = root
        self.includeSubfolders = includeSubfolders
        self.showHidden = showHidden
    }
}

public enum SearchEnd: Equatable, Sendable {
    case finished, limitReached, cancelled
}

/// Finding items by part of their name, in one folder (a filter) or in everything below it.
public enum FileSearch {
    public static let resultLimit = 5_000
    public static let batchSize = 200

    /// Part of the name, ignoring case and accents; empty text matches everything.
    public static func matches(_ name: String, _ text: String) -> Bool {
        text.isEmpty || name.range(of: text, options: [.caseInsensitive, .diacriticInsensitive]) != nil
    }

    public static func filter(_ entries: [FileEntry], text: String) -> [FileEntry] {
        entries.filter { matches($0.name, text) || matches($0.url.lastPathComponent, text) }
    }

    /// Walks everything below `root` without entering packages or following links, skipping folders it
    /// can't read (and hidden items unless asked). Results arrive in batches; it stops at `limit` or on cancel.
    public static func run(_ query: SearchQuery, limit: Int = resultLimit, control: OperationControl,
                           onBatch: @Sendable ([FileEntry]) -> Void) -> SearchEnd {
        var options: FileManager.DirectoryEnumerationOptions = [.skipsPackageDescendants]
        if !query.showHidden { options.insert(.skipsHiddenFiles) }
        guard let enumerator = FileManager.default.enumerator(at: query.root, includingPropertiesForKeys: FolderListing.keys,
                                                              options: options, errorHandler: { _, _ in true }) else { return .finished }
        // The enumerator answers with real paths (/private/var for /var): give results the root's spelling.
        let prefixes = [realPath(query.root), query.root.standardizedFileURL.path].map { $0 == "/" ? "/" : $0 + "/" }
        var batch: [FileEntry] = []
        var found = 0
        while let listed = enumerator.nextObject() as? URL {
            if control.isCancelled { return .cancelled }
            guard matches(listed.lastPathComponent, query.text) else { continue }
            var item = listed
            if let prefix = prefixes.first(where: { listed.path.hasPrefix($0) }) {
                item = query.root.appending(path: String(listed.path.dropFirst(prefix.count)), directoryHint: .notDirectory)
            }
            batch.append(FolderListing.entry(for: item, in: item.deletingLastPathComponent()))
            found += 1
            if found >= limit {
                onBatch(batch)
                return .limitReached
            }
            if batch.count >= batchSize {
                onBatch(batch)
                batch = []
            }
        }
        if !batch.isEmpty { onBatch(batch) }
        return control.isCancelled ? .cancelled : .finished
    }

    /// realpath(3): Foundation's resolvingSymlinksInPath drops "/private", which the enumerator keeps.
    private static func realPath(_ url: URL) -> String {
        guard let resolved = realpath(url.path, nil) else { return url.standardizedFileURL.path }
        defer { free(resolved) }
        return String(cString: resolved)
    }
}
