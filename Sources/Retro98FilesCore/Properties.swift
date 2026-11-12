import Foundation
import Retro98Settings

/// What a folder holds: bytes, files and folders below it.
public struct FolderTally: Equatable, Sendable {
    public var bytes: Int64
    public var files: Int
    public var folders: Int
    public var skippedUnreadable: Bool

    public init(bytes: Int64 = 0, files: Int = 0, folders: Int = 0, skippedUnreadable: Bool = false) {
        self.bytes = bytes
        self.files = files
        self.folders = folders
        self.skippedUnreadable = skippedUnreadable
    }

    public mutating func add(_ other: FolderTally) {
        bytes += other.bytes
        files += other.files
        folders += other.folders
        skippedUnreadable = skippedUnreadable || other.skippedUnreadable
    }
}

/// The Properties window's contents; folders listed in `needsMeasuring` are added to `tally` later.
public struct ItemProperties: Equatable, Sendable {
    public let title: String
    public let name: String
    public let typeName: String
    public let location: String?
    public var tally: FolderTally
    public let needsMeasuring: [URL]
    /// Apps and other packages: measured for their size only (each counts as one item).
    public let packages: [URL]
    public let created: Date?
    public let modified: Date?
    public let accessed: Date?
}

public enum PropertiesReader {
    static let progressInterval = 500

    /// One item: its own details. Several: a count, the shared folder, and the selected items counted
    /// (a single folder counts only what it holds).
    public static func summary(of entries: [FileEntry], languages l: [String]) -> ItemProperties {
        let folders = entries.filter { $0.kind == .folder }.map(\.url)
        let files = entries.filter { $0.kind != .folder }
        let packages = files.filter { (try? $0.url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true }.map(\.url)
        var tally = FolderTally(bytes: files.reduce(0) { $0 + size(of: $1) })
        let parents = Set(entries.map { $0.url.deletingLastPathComponent().standardizedFileURL.path })
        let location = parents.count == 1 ? parents.first.map { ($0 as NSString).abbreviatingWithTildeInPath } : nil
        let types = Set(entries.map { FileTypeName.name(for: $0, languages: l) })
        guard entries.count == 1, let entry = entries.first else {
            tally.files = files.count
            tally.folders = folders.count
            let count = ExplorerText.itemCount(entries.count, l)
            return ItemProperties(title: count, name: count, typeName: types.count == 1 ? types.first ?? "" : ExplorerText.multipleTypes(l),
                                  location: location, tally: tally, needsMeasuring: folders, packages: packages, created: nil, modified: nil,
                                  accessed: nil)
        }
        if entry.kind != .folder { tally.files = 1 }
        let dates = try? entry.url.resourceValues(forKeys: [.creationDateKey, .contentModificationDateKey, .contentAccessDateKey])
        return ItemProperties(title: ExplorerText.propertiesTitle(entry.name, l), name: entry.name, typeName: types.first ?? "",
                              location: location, tally: tally, needsMeasuring: folders, packages: packages, created: dates?.creationDate,
                              modified: dates?.contentModificationDate, accessed: dates?.contentAccessDate)
    }

    /// Adds up everything inside `folder`: links are not followed, folders it can't read are noted.
    public static func measure(_ folder: URL, control: OperationControl, onProgress: @Sendable (FolderTally) -> Void) -> FolderTally {
        final class Flag: @unchecked Sendable { var raised = false }
        let unreadable = Flag()
        var tally = FolderTally()
        guard !control.isCancelled else { return tally }
        let keys: [URLResourceKey] = [.isDirectoryKey, .fileSizeKey]
        guard let enumerator = FileManager.default.enumerator(at: folder, includingPropertiesForKeys: keys, options: [],
                                                              errorHandler: { _, _ in unreadable.raised = true; return true }) else {
            return FolderTally(skippedUnreadable: true)
        }
        var seen = 0
        while let item = enumerator.nextObject() as? URL {
            if control.isCancelled { break }
            let values = try? item.resourceValues(forKeys: Set(keys))
            if values?.isDirectory == true {
                tally.folders += 1
            } else {
                tally.files += 1
                tally.bytes += Int64(values?.fileSize ?? 0)
            }
            seen += 1
            if seen % progressInterval == 0 { onProgress(tally) }
        }
        tally.skippedUnreadable = unreadable.raised
        return tally
    }

    private static func size(of entry: FileEntry) -> Int64 {
        entry.size ?? Int64((try? entry.url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0)
    }
}

public enum PropertiesText {
    /// "1,2 MB (1.234.567 bytes)"; under 1000, just "5 bytes".
    public static func size(_ bytes: Int64, locale: Locale, languages: [String]) -> String {
        guard bytes >= 1000 else { return "\(bytes) bytes" }
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        return "\(StatusText.bytes(bytes, locale: locale)) (\(formatter.string(from: NSNumber(value: bytes)) ?? "\(bytes)") bytes)"
    }

    /// "1 arquivo, 3 pastas".
    public static func contains(files: Int, folders: Int, languages l: [String]) -> String {
        let fileText = files == 1 ? LocalizedText(en: "1 file", ptBR: "1 arquivo") : LocalizedText(en: "\(files) files", ptBR: "\(files) arquivos")
        let folderText = folders == 1
            ? LocalizedText(en: "1 folder", ptBR: "1 pasta") : LocalizedText(en: "\(folders) folders", ptBR: "\(folders) pastas")
        return fileText.resolve(for: l) + ", " + folderText.resolve(for: l)
    }

    public static func volume(_ info: VolumeInfo, locale: Locale, languages: [String])
        -> (used: String, free: String, capacity: String, fraction: Double) {
        let total = info.totalBytes ?? 0, free = info.freeBytes ?? 0, used = max(total - free, 0)
        return (size(used, locale: locale, languages: languages), size(free, locale: locale, languages: languages),
                size(total, locale: locale, languages: languages), total > 0 ? Double(used) / Double(total) : 0)
    }
}

public struct OpenWithChoice: Equatable, Sendable {
    public let app: URL
    public let name: String
    public let isDefault: Bool
}

public enum OpenWithList {
    /// The default app first, then the others by name, each once.
    public static func choices(defaultApp: URL?, apps: [URL]) -> [OpenWithChoice] {
        func name(_ app: URL) -> String {
            let shown = FileManager.default.displayName(atPath: app.path)
            return shown.lowercased().hasSuffix(".app") ? String(shown.dropLast(4)) : shown
        }
        let defaultPath = defaultApp?.standardizedFileURL.path
        var seen = Set<String>()
        let others = apps.filter { app in
            let path = app.standardizedFileURL.path
            return path != defaultPath && seen.insert(path).inserted
        }.map { OpenWithChoice(app: $0, name: name($0), isDefault: false) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        return (defaultApp.map { [OpenWithChoice(app: $0, name: name($0), isDefault: true)] } ?? []) + others
    }
}

/// One window the "reveal" request opens: a folder and the items to select in it.
public struct RevealWindow: Equatable, Sendable {
    public let folder: URL
    public let select: [URL]

    public init(folder: URL, select: [URL]) {
        self.folder = folder
        self.select = select
    }
}

public enum RevealPlan {
    /// Groups by parent folder in order of appearance; a folder asked for alone opens on itself.
    public static func windows(for urls: [URL]) -> [RevealWindow] {
        if urls.count == 1, let only = urls.first, (try? only.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true,
           (try? only.resourceValues(forKeys: [.isPackageKey]))?.isPackage != true {
            return [RevealWindow(folder: only, select: [])]
        }
        var order: [String] = []
        var groups: [String: (folder: URL, select: [URL])] = [:]
        for url in urls {
            let key = url.deletingLastPathComponent().standardizedFileURL.path
            if groups[key] == nil {
                order.append(key)
                groups[key] = (URL(filePath: key, directoryHint: .notDirectory), [])
            }
            groups[key]?.select.append(url)
        }
        return order.compactMap { groups[$0].map { RevealWindow(folder: $0.folder, select: $0.select) } }
    }
}
