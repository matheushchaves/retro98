import Foundation
import UniformTypeIdentifiers

public enum ViewMode: String, CaseIterable, Sendable {
    case largeIcons, smallIcons, list, details
}

public enum SortKey: String, CaseIterable, Sendable {
    case name, type, size, modified
}

public struct SortOrder: Equatable, Sendable {
    public var key: SortKey
    public var ascending: Bool

    public init(key: SortKey, ascending: Bool) {
        self.key = key
        self.ascending = ascending
    }

    public static let byName = SortOrder(key: .name, ascending: true)
}

/// The "Type" column: our names for places, folders and apps, the system's for declared file
/// types, and "Arquivo EXT" for the rest.
public enum FileTypeName {
    public static func name(for entry: FileEntry, languages l: [String]) -> String {
        switch entry.kind {
        case .folder: return ExplorerText.typeFolder(l)
        case .application: return ExplorerText.typeApplication(l)
        case .volume(.internal): return ExplorerText.typeLocalDisk(l)
        case .volume(.removable): return ExplorerText.typeRemovableDisk(l)
        case .volume(.network): return ExplorerText.typeNetworkDrive(l)
        case .myComputer, .myDocuments, .recycleBin: return ExplorerText.typeSystemFolder(l)
        default:
            let ext = entry.url.pathExtension
            guard !ext.isEmpty else { return ExplorerText.typeFile(l) }
            return cache.description(for: ext.lowercased()) ?? ExplorerText.typeFile(ext.uppercased(), l)
        }
    }

    /// The system's description of a declared type, looked up once per extension (folders can hold thousands).
    private final class Cache: @unchecked Sendable {
        private let lock = NSLock()
        private var descriptions: [String: String?] = [:]

        func description(for ext: String) -> String? {
            if let known = lock.withLock({ descriptions[ext] }) { return known }
            let type = UTType(filenameExtension: ext)
            let found = type.flatMap { $0.isDynamic ? nil : $0.localizedDescription }
            lock.withLock { descriptions[ext] = .some(found) }
            return found
        }
    }

    private static let cache = Cache()
}

public enum FileSorting {
    /// Places (My Computer, My Documents, Recycle Bin, disks) first in the order they came, then folders,
    /// then everything else, each group by the key; ties fall back to the name.
    public static func sorted(_ entries: [FileEntry], by order: SortOrder, languages: [String]) -> [FileEntry] {
        let places = entries.filter { !$0.isFileItem }
        let items = entries.filter(\.isFileItem)
        let types = order.key == .type ? Dictionary(items.map { ($0.url, FileTypeName.name(for: $0, languages: languages)) },
                                                    uniquingKeysWith: { first, _ in first }) : [:]
        func sortedGroup(_ group: [FileEntry]) -> [FileEntry] {
            group.sorted { lhs, rhs in
                let primary = compare(lhs, rhs, key: order.key, types: types)
                if primary != .orderedSame { return order.ascending ? primary == .orderedAscending : primary == .orderedDescending }
                return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            }
        }
        return places + sortedGroup(items.filter { $0.kind == .folder }) + sortedGroup(items.filter { $0.kind != .folder })
    }

    private static func compare(_ lhs: FileEntry, _ rhs: FileEntry, key: SortKey, types: [URL: String]) -> ComparisonResult {
        switch key {
        case .name:
            return lhs.name.localizedStandardCompare(rhs.name)
        case .type:
            return (types[lhs.url] ?? "").localizedStandardCompare(types[rhs.url] ?? "")
        case .size:
            let a = lhs.size ?? -1, b = rhs.size ?? -1
            return a == b ? .orderedSame : (a < b ? .orderedAscending : .orderedDescending)
        case .modified:
            let a = lhs.modified ?? .distantPast, b = rhs.modified ?? .distantPast
            return a == b ? .orderedSame : (a < b ? .orderedAscending : .orderedDescending)
        }
    }
}

/// View mode, sort order and hidden files, shared by every Explorer window and kept between launches.
/// Tests use `.memory`, which never touches the user's defaults.
public final class ExplorerPreferences: @unchecked Sendable {
    private enum Key {
        static let viewMode = "ViewMode", sortKey = "SortKey", sortAscending = "SortAscending", showHidden = "ShowHidden"
    }

    private let lock = NSLock()
    private let defaults: UserDefaults?
    private var memory: [String: Any] = [:]

    public init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    private init(memory: [String: Any]) {
        defaults = nil
        self.memory = memory
    }

    public static func memory(showHidden: Bool = false) -> ExplorerPreferences {
        ExplorerPreferences(memory: [Key.showHidden: showHidden])
    }

    public var viewMode: ViewMode {
        get { (value(Key.viewMode) as? String).flatMap(ViewMode.init(rawValue:)) ?? .largeIcons }
        set { set(newValue.rawValue, Key.viewMode) }
    }

    public var sort: SortOrder {
        get {
            SortOrder(key: (value(Key.sortKey) as? String).flatMap(SortKey.init(rawValue:)) ?? .name,
                      ascending: value(Key.sortAscending) as? Bool ?? true)
        }
        set {
            set(newValue.key.rawValue, Key.sortKey)
            set(newValue.ascending, Key.sortAscending)
        }
    }

    public var showHidden: Bool {
        get { value(Key.showHidden) as? Bool ?? false }
        set { set(newValue, Key.showHidden) }
    }

    private func value(_ key: String) -> Any? {
        lock.withLock { defaults?.object(forKey: key) ?? memory[key] }
    }

    private func set(_ value: Any, _ key: String) {
        lock.withLock {
            if let defaults { defaults.set(value, forKey: key) } else { memory[key] = value }
        }
    }
}
