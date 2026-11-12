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

    /// The defaults keep tests away from the real Trash: items go into `trash` under a free name,
    /// and records go under `home`.
    public init(home: URL, languages: [String], showHidden: Bool, volumes: @escaping @Sendable () -> [VolumeInfo], trash: URL,
                supportDirectory: URL? = nil, moveToTrash: (@Sendable (URL) throws -> URL)? = nil,
                isSameVolume: (@Sendable (URL, URL) -> Bool)? = nil) {
        self.home = home
        self.languages = languages
        self.showHidden = showHidden
        self.volumes = volumes
        self.trash = trash
        self.supportDirectory = supportDirectory ?? home.appending(path: "Library/Application Support/Retro98")
        self.moveToTrash = moveToTrash ?? { try Self.move($0, into: trash) }
        self.isSameVolume = isSameVolume ?? { Volumes.same($0, $1) }
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
            })
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
    private let environment: ExplorerEnvironment

    public init(start: Location, environment: ExplorerEnvironment) {
        self.environment = environment
        history = NavigationHistory(start: start)
        load()
    }

    public var title: String { ExplorerText.locationTitle(history.current, environment.languages) }

    public func go(to location: Location) {
        history.go(to: location)
        load()
    }

    public func back() {
        history.back()
        load()
    }

    public func forward() {
        history.forward()
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
        if case .folder(let url) = history.current, !FileManager.default.fileExists(atPath: url.path) {
            let recovered = NavigationHistory.recover(history.current, exists: { FileManager.default.fileExists(atPath: $0.path) },
                                                      volumes: volumes.map(\.url))
            history.go(to: recovered)
        }
        load(readingVolumes: false)
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
        onChange?()
    }

    private func list(_ folder: URL) -> [FileEntry]? {
        do {
            return try FolderListing.entries(of: folder, showHidden: environment.showHidden)
        } catch {
            switch error {
            case .permissionDenied: self.error = ExplorerText.permissionDenied(environment.languages)
            case .notFound: self.error = ExplorerText.notFound(folder.path, environment.languages)
            }
            return nil
        }
    }
}
