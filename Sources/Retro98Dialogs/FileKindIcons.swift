import Retro98FilesCore
import Retro98UI

extension FileKind {
    /// The retro icon for this kind of item (apps show a folder until their own icon is loaded).
    public var iconKind: FileIconKind {
        switch self {
        case .folder, .application: .folder
        case .image: .image
        case .audio: .audio
        case .video: .video
        case .archive: .archive
        case .text: .text
        case .document: .document
        case .volume(.internal): .hardDisk
        case .volume(.removable): .removableDisk
        case .volume(.network): .networkDisk
        case .myComputer: .myComputer
        case .myDocuments: .myDocuments
        case .recycleBin(let isFull): isFull == true ? .recycleBinFull : .recycleBinEmpty
        }
    }
}
