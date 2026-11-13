import Foundation

public enum FileDialogMode: Sendable {
    case open, save
}

/// One line of a dialog's "Files of type" list.
public struct FileTypeFilter: Equatable, Sendable {
    public let title: String
    /// Lowercased, no dot; empty lets every file through.
    public let extensions: [String]

    public init(title: String, extensions: [String]) {
        self.title = title
        self.extensions = extensions.map { $0.lowercased() }
    }

    /// What a name typed without an extension gets when saving.
    public var defaultExtension: String? { extensions.first }

    public func matches(_ url: URL) -> Bool {
        extensions.isEmpty || extensions.contains(url.pathExtension.lowercased())
    }
}

/// What pressing Open or Save does with the text in the name field.
public enum FileDialogOutcome: Equatable, Sendable {
    /// The field is empty.
    case nothing
    /// A folder: show it.
    case navigate(URL)
    /// Done.
    case choose(URL)
    /// Save over an existing file: ask first.
    case confirmReplace(URL)
    /// Open: no such file (the typed text).
    case notFound(String)
    /// Save: the name has a ":" (the typed text).
    case invalidName(String)
    /// Save: the folder part doesn't exist (its path).
    case folderNotFound(String)
}

/// A line of the "Look in" list.
public struct FileDialogPlace: Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        case desktop, documents, volume(VolumeKind), folder
    }

    public let url: URL
    public let name: String
    public let kind: Kind
    /// How far to indent it.
    public let depth: Int
}

/// The open and save dialogs' rules, with no window involved.
public enum FileDialogLogic {
    /// Subfolders and the files `filter` lets through; no hidden files, no packages; folders first.
    public static func entries(of folder: URL, filter: FileTypeFilter, fileManager: FileManager = .default)
        throws(FolderListingError) -> [FileEntry] {
        try FolderListing.entries(of: folder, showHidden: false, fileManager: fileManager).filter { entry in
            if entry.kind == .folder { return true }
            if entry.kind == .application || isDirectory(entry.url.path, fileManager) { return false }
            return filter.matches(entry.url)
        }
    }

    /// What pressing Open/Save with `text` in the name field does, from `folder`: a name, a relative path,
    /// an absolute path or one starting at "~" (the home folder).
    public static func resolve(_ text: String, in folder: URL, mode: FileDialogMode, filter: FileTypeFilter, home: URL,
                               fileManager: FileManager = .default) -> FileDialogOutcome {
        let typed = text.trimmingCharacters(in: .whitespaces)
        guard !typed.isEmpty else { return .nothing }
        let path: String
        if typed == "~" {
            path = home.path
        } else if typed.hasPrefix("~/") {
            path = home.path + typed.dropFirst()
        } else if typed.hasPrefix("/") {
            path = typed
        } else {
            path = folder.path + "/" + typed
        }
        let url = URL(filePath: path).standardizedFileURL
        if isDirectory(url.path, fileManager) { return .navigate(url) }
        switch mode {
        case .open:
            return fileManager.fileExists(atPath: url.path) ? .choose(url) : .notFound(typed)
        case .save:
            // The Finder shows "/" in a name as ":", so a ":" can't be part of one.
            guard !url.lastPathComponent.contains(":") else { return .invalidName(typed) }
            let parent = url.deletingLastPathComponent()
            guard isDirectory(parent.path, fileManager) else { return .folderNotFound(parent.path) }
            var target = url
            if target.pathExtension.isEmpty, let added = filter.defaultExtension { target.appendPathExtension(added) }
            if isDirectory(target.path, fileManager) { return .navigate(target) }
            return fileManager.fileExists(atPath: target.path) ? .confirmReplace(target) : .choose(target)
        }
    }

    /// Desktop; each volume, with the current folder's chain under its own volume; My Documents.
    public static func places(current: URL, home: URL, volumes: [VolumeInfo], languages: [String]) -> [FileDialogPlace] {
        var places = [FileDialogPlace(url: home.appending(path: "Desktop"), name: ExplorerText.desktop(languages), kind: .desktop, depth: 0)]
        let currentPath = current.standardizedFileURL.path
        let own = Volumes.containing(path: currentPath, in: volumes)
        for volume in volumes {
            places.append(FileDialogPlace(url: volume.url, name: volume.name, kind: .volume(volume.kind), depth: 1))
            guard volume == own else { continue }
            var path = volume.url.path
            let below = currentPath.dropFirst(path.count).split(separator: "/")
            for (index, component) in below.enumerated() {
                path = (path == "/" ? "" : path) + "/" + component
                places.append(FileDialogPlace(url: URL(filePath: path), name: FileManager.default.displayName(atPath: path),
                                              kind: .folder, depth: 2 + index))
            }
        }
        places.append(FileDialogPlace(url: home.appending(path: "Documents"), name: ExplorerText.myDocuments(languages),
                                      kind: .documents, depth: 1))
        return places
    }

    private static func isDirectory(_ path: String, _ fileManager: FileManager) -> Bool {
        var isDirectory: ObjCBool = false
        return fileManager.fileExists(atPath: path, isDirectory: &isDirectory) && isDirectory.boolValue
    }
}
