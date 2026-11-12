import Foundation
import Retro98Settings

/// What an Explorer window needs from the outside world (injectable in tests).
public struct ExplorerEnvironment: Sendable {
    public let home: URL
    public let languages: [String]
    public let showHidden: Bool
    public let volumes: @Sendable () -> [VolumeInfo]
    public let trash: URL
    /// Where the Explorer keeps its own records (where trashed items came from).
    public let supportDirectory: URL
    /// Sends an item to the Trash and returns where it went.
    public let moveToTrash: @Sendable (URL) throws -> URL
    public let isSameVolume: @Sendable (URL, URL) -> Bool
    /// View mode, sort order and hidden files shared by every window.
    public let preferences: ExplorerPreferences

    /// The defaults keep tests away from the real Trash: items go into `trash` under a free name,
    /// and records go under `home`.
    public init(home: URL, languages: [String], showHidden: Bool, volumes: @escaping @Sendable () -> [VolumeInfo], trash: URL,
                supportDirectory: URL? = nil, moveToTrash: (@Sendable (URL) throws -> URL)? = nil,
                isSameVolume: (@Sendable (URL, URL) -> Bool)? = nil, preferences: ExplorerPreferences? = nil) {
        self.home = home
        self.languages = languages
        self.showHidden = showHidden
        self.volumes = volumes
        self.trash = trash
        self.supportDirectory = supportDirectory ?? home.appending(path: "Library/Application Support/Retro98")
        self.moveToTrash = moveToTrash ?? { try Self.move($0, into: trash) }
        self.isSameVolume = isSameVolume ?? { Volumes.same($0, $1) }
        self.preferences = preferences ?? .memory(showHidden: showHidden)
    }

    public static func live(languages: [String]) -> ExplorerEnvironment {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return ExplorerEnvironment(
            home: home, languages: languages, showHidden: false, volumes: { Volumes.mounted() }, trash: home.appending(path: ".Trash"),
            supportDirectory: Retro98Paths.standard(home: home, environment: ProcessInfo.processInfo.environment).supportDirectory,
            moveToTrash: { url in
                var trashed: NSURL?
                try FileManager.default.trashItem(at: url, resultingItemURL: &trashed)
                return (trashed as URL?) ?? url
            },
            preferences: ExplorerPreferences(defaults: .standard))
    }

    private static func move(_ item: URL, into trash: URL) throws -> URL {
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: trash, withIntermediateDirectories: true)
        let values = try? item.resourceValues(forKeys: [.isDirectoryKey, .isPackageKey])
        let name = FileNames.available(item.lastPathComponent, isFolder: values?.isDirectory == true && values?.isPackage != true,
                                       existing: Set((try? fileManager.contentsOfDirectory(atPath: trash.path)) ?? []))
        let target = trash.appending(path: name, directoryHint: .notDirectory)
        try fileManager.moveItem(at: item, to: target)
        return target
    }
}

/// The state of one Explorer window: where it is, what it lists, and any message to show instead.
@MainActor
public final class ExplorerModel {
    public private(set) var history: NavigationHistory
    public private(set) var entries: [FileEntry] = []
    public private(set) var error: String?
    public var onChange: (() -> Void)?
    /// Mounted volumes and the free space where the window is, read once per load: a stale network
    /// mount can block that call for seconds, so it must never run per click.
    public private(set) var volumes: [VolumeInfo] = []
    public private(set) var freeSpace: Int64?
    public private(set) var sort: SortOrder
    public private(set) var showHidden: Bool
    /// While searching, `entries` holds the matches instead of the listing.
    public private(set) var search: SearchQuery?
    /// nil while a search in subfolders is still running.
    public private(set) var searchEnd: SearchEnd?
    private var listed: [FileEntry] = []
    private var results: [FileEntry] = []
    private let environment: ExplorerEnvironment

    public init(start: Location, environment: ExplorerEnvironment) {
        self.environment = environment
        history = NavigationHistory(start: start)
        sort = environment.preferences.sort
        showHidden = environment.preferences.showHidden
        load()
    }

    /// Re-sorts what is listed (no disk read) and remembers the order for every window.
    public func setSort(_ order: SortOrder) {
        sort = order
        environment.preferences.sort = order
        listed = FileSorting.sorted(listed, by: order, languages: environment.languages)
        entries = FileSorting.sorted(entries, by: order, languages: environment.languages)
        onChange?()
    }

    // MARK: Search

    /// Without subfolders, filters what is listed right away; with them, waits for `addResults`.
    public func beginSearch(_ query: SearchQuery) {
        search = query
        results = []
        if query.includeSubfolders {
            entries = []
            searchEnd = nil
        } else {
            entries = FileSearch.filter(listed, text: query.text)
            searchEnd = .finished
        }
        onChange?()
    }

    public func addResults(_ batch: [FileEntry]) {
        guard search?.includeSubfolders == true else { return }
        results += batch
        entries = FileSorting.sorted(results, by: sort, languages: environment.languages)
        onChange?()
    }

    public func finishSearch(_ end: SearchEnd) {
        searchEnd = end
        onChange?()
    }

    /// Back to the listing of the place (navigating ends a search too).
    public func endSearch() {
        clearSearch()
        load(readingVolumes: false)
    }

    private func clearSearch() {
        search = nil
        searchEnd = nil
        results = []
    }

    public func setShowHidden(_ show: Bool) {
        showHidden = show
        environment.preferences.showHidden = show
        reload()
    }

    /// Another window changed the shared preferences.
    public func applyPreferences() {
        sort = environment.preferences.sort
        showHidden = environment.preferences.showHidden
        reload()
    }

    public var title: String { ExplorerText.locationTitle(history.current, environment.languages) }

    public func go(to location: Location) {
        clearSearch()
        history.go(to: location)
        load()
    }

    /// A folder deleted or moved since it was visited is replaced by its nearest existing parent.
    public func back() {
        clearSearch()
        history.back()
        recoverIfVanished()
        load()
    }

    public func forward() {
        clearSearch()
        history.forward()
        recoverIfVanished()
        load()
    }

    public func up() {
        guard let parent = NavigationHistory.parent(of: history.current, volumes: volumes.map(\.url)) else { return }
        go(to: parent)
    }

    /// Places navigate (returns nil); files and apps return the URL to open with NSWorkspace.
    public func open(_ entry: FileEntry) -> URL? {
        guard let location = entry.location else { return entry.url }
        go(to: location)
        return nil
    }

    /// Re-reads the current place; if it no longer exists, moves up to the nearest place that does.
    public func reload() {
        volumes = environment.volumes()
        recoverIfVanished()
        load(readingVolumes: false)
    }

    private func recoverIfVanished() {
        guard case .folder(let url) = history.current, !FileManager.default.fileExists(atPath: url.path) else { return }
        history.replaceCurrent(with: NavigationHistory.recover(history.current, exists: { FileManager.default.fileExists(atPath: $0.path) },
                                                               volumes: volumes.map(\.url)))
    }

    private func load(readingVolumes: Bool = true) {
        error = nil
        if readingVolumes { volumes = environment.volumes() }
        let languages = environment.languages
        let path: String
        switch history.current {
        case .folder(let url): path = url.path
        default: path = environment.home.path
        }
        freeSpace = Volumes.containing(path: path, in: volumes)?.freeBytes
        switch history.current {
        case .desktop:
            entries = DesktopLocation.entries(desktop: environment.home.appending(path: "Desktop"),
                                              documents: environment.home.appending(path: "Documents"),
                                              trash: environment.trash, languages: languages)
        case .myComputer:
            entries = volumes.map { volume in
                FileEntry(url: volume.url, name: volume.name, kind: .volume(volume.kind), size: volume.totalBytes,
                          modified: nil, location: .folder(volume.url))
            }
        case .trash:
            entries = list(environment.trash) ?? []
            if TrashState.isFull(trash: environment.trash) == nil {
                entries = []
                error = ExplorerText.trashNeedsAccess(languages)
            }
        case .folder(let url):
            entries = list(url) ?? []
        }
        listed = FileSorting.sorted(entries, by: sort, languages: languages)
        // A reload during a search refreshes the filter; matches from subfolders stay as they are.
        if let search {
            entries = search.includeSubfolders
                ? FileSorting.sorted(results, by: sort, languages: languages)
                : FileSearch.filter(listed, text: search.text)
        } else {
            entries = listed
        }
        onChange?()
    }

    private func list(_ folder: URL) -> [FileEntry]? {
        do {
            return try FolderListing.entries(of: folder, showHidden: showHidden)
        } catch {
            switch error {
            case .permissionDenied: self.error = ExplorerText.permissionDenied(environment.languages)
            case .notFound: self.error = ExplorerText.notFound(folder.path, environment.languages)
            }
            return nil
        }
    }
}
