import Foundation

/// A place the Explorer can show.
public enum Location: Hashable, Sendable {
    case desktop, myComputer, trash
    case folder(URL)
}

public enum VolumeKind: Equatable, Sendable {
    case `internal`, removable, network
}

public enum FileKind: Equatable, Sendable {
    case folder, application, image, audio, video, archive, text, document
    case volume(VolumeKind), myComputer, myDocuments
    case recycleBin(isFull: Bool?)
}

public struct FileEntry: Equatable, Sendable {
    public let url: URL
    public let name: String
    public let kind: FileKind
    public let size: Int64?
    public let modified: Date?
    /// Where opening goes; nil means open with an app.
    public let location: Location?
    /// A dot file or one flagged hidden (listed only when hidden files are shown, and drawn ghosted).
    public let isHidden: Bool

    public init(url: URL, name: String, kind: FileKind, size: Int64?, modified: Date?, location: Location?, isHidden: Bool = false) {
        self.url = url
        self.name = name
        self.kind = kind
        self.size = size
        self.modified = modified
        self.location = location
        self.isHidden = isHidden
    }
}
