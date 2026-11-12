import Foundation
import UniformTypeIdentifiers

public enum FileKindClassifier {
    public static func kind(for url: URL, isDirectory: Bool, isPackage: Bool) -> FileKind {
        if isPackage && url.pathExtension.lowercased() == "app" { return .application }
        if isDirectory && !isPackage { return .folder }
        guard let type = UTType(filenameExtension: url.pathExtension) else { return .document }
        if type.conforms(to: .image) { return .image }
        if type.conforms(to: .audio) { return .audio }
        if type.conforms(to: .movie) { return .video }
        if type.conforms(to: .archive) { return .archive }
        if type.conforms(to: .sourceCode) || type.conforms(to: .plainText) { return .text }
        return .document
    }
}

public enum FolderListingError: Error, Equatable {
    case notFound, permissionDenied
}

public enum FolderListing {
    /// Prefetched for every entry. The localized name is not: it costs more than everything else
    /// together and only folders and apps use it.
    static let keys: [URLResourceKey] = [.isDirectoryKey, .isPackageKey, .fileSizeKey, .contentModificationDateKey, .isHiddenKey]

    /// Folders first, then by name (Finder order); hidden files only when asked; packages are items.
    public static func entries(of folder: URL, showHidden: Bool, fileManager: FileManager = .default)
        throws(FolderListingError) -> [FileEntry] {
        let urls: [URL]
        do {
            urls = try fileManager.contentsOfDirectory(at: folder, includingPropertiesForKeys: keys,
                                                       options: showHidden ? [] : [.skipsHiddenFiles])
        } catch {
            throw fileManager.fileExists(atPath: folder.path) ? .permissionDenied : .notFound
        }
        let entries = urls.map { entry(for: $0, in: folder) }
        return entries.sorted { lhs, rhs in
            let lhsFolder = lhs.kind == .folder, rhsFolder = rhs.kind == .folder
            if lhsFolder != rhsFolder { return lhsFolder }
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }
    }

    static func entry(for listed: URL, in folder: URL) -> FileEntry {
        let values = try? listed.resourceValues(forKeys: Set(keys))
        let isDirectory = values?.isDirectory ?? false
        let isPackage = values?.isPackage ?? false
        // Rebuild from the folder we were given, so paths match what callers pass around.
        let url = folder.appending(path: listed.lastPathComponent, directoryHint: .notDirectory)
        let kind = FileKindClassifier.kind(for: url, isDirectory: isDirectory, isPackage: isPackage)
        let localizedName = { (try? url.resourceValues(forKeys: [.localizedNameKey]).localizedName) ?? url.lastPathComponent }
        let name: String
        switch kind {
        case .application:
            let localized = localizedName()
            name = localized.lowercased().hasSuffix(".app") ? String(localized.dropLast(4)) : localized
        case .folder: name = localizedName()
        default: name = url.lastPathComponent
        }
        return FileEntry(url: url, name: name, kind: kind, size: values?.fileSize.map(Int64.init),
                         modified: values?.contentModificationDate, location: kind == .folder ? .folder(url) : nil,
                         isHidden: values?.isHidden ?? false)
    }
}

public struct VolumeInfo: Equatable, Sendable {
    public let url: URL
    public let name: String
    public let kind: VolumeKind
    public let totalBytes: Int64?
    public let freeBytes: Int64?
    public let isEjectable: Bool
}

public enum Volumes {
    /// The innermost volume that holds `path` (e.g. /Volumes/PEN rather than /).
    public static func containing(path: String, in volumes: [VolumeInfo]) -> VolumeInfo? {
        volumes.filter { path == $0.url.path || path.hasPrefix($0.url.path == "/" ? "/" : $0.url.path + "/") }
            .max { $0.url.path.count < $1.url.path.count }
    }

    /// Whether two items live on the same volume (a move there is a rename); false when either can't be read.
    public static func same(_ a: URL, _ b: URL) -> Bool {
        guard let first = try? a.resourceValues(forKeys: [.volumeIdentifierKey]).volumeIdentifier,
              let second = try? b.resourceValues(forKeys: [.volumeIdentifierKey]).volumeIdentifier else { return false }
        return first.isEqual(second)
    }

    public static func mounted(fileManager: FileManager = .default) -> [VolumeInfo] {
        let keys: [URLResourceKey] = [.volumeNameKey, .volumeIsRemovableKey, .volumeIsEjectableKey, .volumeIsInternalKey,
                                      .volumeIsLocalKey, .volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey]
        let urls = fileManager.mountedVolumeURLs(includingResourceValuesForKeys: keys, options: [.skipHiddenVolumes]) ?? []
        return urls.compactMap { url in
            guard let values = try? url.resourceValues(forKeys: Set(keys)) else { return nil }
            let kind: VolumeKind
            if values.volumeIsLocal == false {
                kind = .network
            } else if values.volumeIsRemovable == true || (values.volumeIsEjectable == true && values.volumeIsInternal != true) {
                kind = .removable
            } else {
                kind = .internal
            }
            return VolumeInfo(url: URL(filePath: url.path), name: values.volumeName ?? url.lastPathComponent, kind: kind,
                              totalBytes: values.volumeTotalCapacity.map(Int64.init),
                              freeBytes: values.volumeAvailableCapacityForImportantUsage, isEjectable: values.volumeIsEjectable ?? false)
        }
    }
}

public enum DesktopLocation {
    /// My Computer, My Documents and the Recycle Bin, then the files of the Desktop folder
    /// (only the fixed items when the Desktop can't be read).
    public static func entries(desktop: URL, documents: URL, trash: URL, languages: [String],
                               fileManager: FileManager = .default) -> [FileEntry] {
        let fixed = [
            FileEntry(url: URL(filePath: "/"), name: ExplorerText.myComputer(languages), kind: .myComputer,
                      size: nil, modified: nil, location: .myComputer),
            FileEntry(url: documents, name: ExplorerText.myDocuments(languages), kind: .myDocuments,
                      size: nil, modified: nil, location: .folder(documents)),
            FileEntry(url: trash, name: ExplorerText.recycleBin(languages), kind: .recycleBin(isFull: TrashState.isFull(trash: trash)),
                      size: nil, modified: nil, location: .trash),
        ]
        let files = (try? FolderListing.entries(of: desktop, showHidden: false, fileManager: fileManager)) ?? []
        return fixed + files
    }
}

public enum TrashState {
    /// true = has visible items, false = empty, nil = not allowed to read it.
    public static func isFull(trash: URL, fileManager: FileManager = .default) -> Bool? {
        guard let names = try? fileManager.contentsOfDirectory(atPath: trash.path) else { return nil }
        return names.contains { !$0.hasPrefix(".") }
    }
}

/// Calls back when a folder's contents change (file system events on its descriptor).
public final class DirectoryWatcher {
    private let source: DispatchSourceFileSystemObject

    public init?(url: URL, onChange: @escaping @Sendable () -> Void) {
        let descriptor = open(url.path, O_EVTONLY)
        guard descriptor >= 0 else { return nil }
        source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: descriptor, eventMask: [.write, .delete, .rename, .extend],
                                                           queue: .main)
        source.setEventHandler(handler: onChange)
        source.setCancelHandler { close(descriptor) }
        source.resume()
    }

    public func stop() { source.cancel() }

    deinit { source.cancel() }
}
