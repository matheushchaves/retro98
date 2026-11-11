import AppKit
import Retro98FilesCore
import Retro98UI

/// Tree data: Desktop › (My Computer › volumes › folders), My Documents, Downloads, Recycle Bin.
/// Folder ids are "folder:<path>"; children load lazily (subfolders only).
@MainActor
final class ExplorerTree: RetroTreeDataSource {
    static let desktopID = "desktop", myComputerID = "myComputer", trashID = "trash"

    private let environment: ExplorerEnvironment
    private let languages: [String]
    private var volumes: [VolumeInfo]

    init(environment: ExplorerEnvironment, languages: [String]) {
        self.environment = environment
        self.languages = languages
        volumes = environment.volumes()
    }

    func reset() { volumes = environment.volumes() }

    private var documents: URL { environment.home.appending(path: "Documents", directoryHint: .notDirectory) }
    private var downloads: URL { environment.home.appending(path: "Downloads", directoryHint: .notDirectory) }

    static func folderID(_ url: URL) -> String { "folder:" + url.path }

    func location(for id: String) -> Location? {
        switch id {
        case Self.desktopID: return .desktop
        case Self.myComputerID: return .myComputer
        case Self.trashID: return .trash
        default:
            guard id.hasPrefix("folder:") else { return nil }
            return .folder(URL(filePath: String(id.dropFirst("folder:".count))))
        }
    }

    /// Ids from the root down to `location`, for revealing it in the tree.
    func path(to location: Location) -> [String] {
        switch location {
        case .desktop: return [Self.desktopID]
        case .myComputer: return [Self.desktopID, Self.myComputerID]
        case .trash: return [Self.desktopID, Self.trashID]
        case .folder(let url):
            for shortcut in [documents, downloads] where url.path == shortcut.path || url.path.hasPrefix(shortcut.path + "/") {
                return [Self.desktopID] + chain(from: shortcut, to: url)
            }
            let volume = volumes.filter { url.path == $0.url.path || url.path.hasPrefix($0.url.path == "/" ? "/" : $0.url.path + "/") }
                .max { $0.url.path.count < $1.url.path.count }
            guard let volume else { return [Self.desktopID, Self.folderID(url)] }
            return [Self.desktopID, Self.myComputerID] + chain(from: volume.url, to: url)
        }
    }

    private func chain(from root: URL, to url: URL) -> [String] {
        var ids = [Self.folderID(root)]
        var current = root.path == "/" ? "" : root.path
        let rest = url.path.dropFirst(current.count).split(separator: "/")
        for component in rest {
            current += "/" + component
            ids.append(Self.folderID(URL(filePath: current)))
        }
        return ids
    }

    // MARK: RetroTreeDataSource

    func tree(_ tree: RetroTreeView, childrenOf id: String) -> [String] {
        switch id {
        case Self.desktopID: return [Self.myComputerID, Self.folderID(documents), Self.folderID(downloads), Self.trashID]
        case Self.myComputerID: return volumes.map { Self.folderID($0.url) }
        default:
            guard case .folder(let url) = location(for: id),
                  let entries = try? FolderListing.entries(of: url, showHidden: false) else { return [] }
            return entries.filter { $0.kind == .folder }.map { Self.folderID($0.url) }
        }
    }

    func tree(_ tree: RetroTreeView, titleOf id: String) -> String {
        switch id {
        case Self.desktopID: return ExplorerText.desktop(languages)
        case Self.myComputerID: return ExplorerText.myComputer(languages)
        case Self.trashID: return ExplorerText.recycleBin(languages)
        default:
            guard case .folder(let url) = location(for: id) else { return id }
            if url.path == documents.path { return ExplorerText.myDocuments(languages) }
            if let volume = volumes.first(where: { $0.url.path == url.path }) { return volume.name }
            return FileManager.default.displayName(atPath: url.path)
        }
    }

    func tree(_ tree: RetroTreeView, iconOf id: String) -> PixelIcon {
        switch id {
        case Self.desktopID: return FileIcons.icon(.desktop, size: 16)
        case Self.myComputerID: return FileIcons.icon(.myComputer, size: 16)
        case Self.trashID:
            return FileIcons.icon(TrashState.isFull(trash: environment.trash) == true ? .recycleBinFull : .recycleBinEmpty, size: 16)
        default:
            guard case .folder(let url) = location(for: id) else { return FileIcons.icon(.folder, size: 16) }
            if url.path == documents.path { return FileIcons.icon(.myDocuments, size: 16) }
            if let volume = volumes.first(where: { $0.url.path == url.path }) {
                return FileIcons.icon(ExplorerIcons.kind(for: .volume(volume.kind)), size: 16)
            }
            return FileIcons.icon(.folder, size: 16)
        }
    }

    func tree(_ tree: RetroTreeView, isExpandable id: String) -> Bool { id != Self.trashID }
}
