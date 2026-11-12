import Foundation
import Retro98Settings

public enum FileOperationKind: Equatable, Sendable {
    case copy, move
}

public enum FileNames {
    /// "foto cópia.jpg", "foto cópia 2.jpg"… (Finder). Plain folders have no extension ("v1.2 cópia"); packages do ("Calc cópia.app").
    public static func copyName(for item: URL, isFolder: Bool, existing: Set<String>, languages: [String]) -> String {
        let (base, ext) = split(item.lastPathComponent, isFolder: isFolder)
        let word = LocalizedText(en: "copy", ptBR: "cópia").resolve(for: languages)
        return first(in: existing) { $0 == 1 ? join("\(base) \(word)", ext) : join("\(base) \(word) \($0)", ext) }
    }

    /// "Nova pasta", "Nova pasta (2)"… (98).
    public static func newFolderName(existing: Set<String>, languages: [String]) -> String {
        let base = ExplorerText.newFolder(languages)
        return first(in: existing) { $0 == 1 ? base : "\(base) (\($0))" }
    }

    /// The name itself, or "<base> 2<.ext>", "<base> 3<.ext>"… when it is taken.
    public static func available(_ name: String, isFolder: Bool, existing: Set<String>) -> String {
        let (base, ext) = split(name, isFolder: isFolder)
        return first(in: existing) { $0 == 1 ? name : join("\(base) \($0)", ext) }
    }

    private static func split(_ name: String, isFolder: Bool) -> (base: String, ext: String) {
        let ext = (name as NSString).pathExtension
        guard !isFolder, !ext.isEmpty else { return (name, "") }
        return ((name as NSString).deletingPathExtension, ext)
    }

    private static func join(_ base: String, _ ext: String) -> String { ext.isEmpty ? base : "\(base).\(ext)" }

    /// Names are compared the way APFS does: ignoring case and Unicode normalization.
    private static func first(in existing: Set<String>, _ candidate: (Int) -> String) -> String {
        let taken = Set(existing.map { $0.precomposedStringWithCanonicalMapping.lowercased() })
        var number = 1
        while taken.contains(candidate(number).precomposedStringWithCanonicalMapping.lowercased()) { number += 1 }
        return candidate(number)
    }
}

public enum RenameCheck: Equatable, Sendable {
    case unchanged
    case accept(String)
    case invalid(String)
    case confirmExtensionChange(from: String, to: String)
    case confirmHidden(String)
}

public enum RenameRules {
    static let maxNameBytes = 255

    /// Trims spaces at the ends; "unchanged" uses Swift's == (NFC and NFD spellings are equal).
    public static func check(original: String, typed: String, isFolder: Bool, languages: [String]) -> RenameCheck {
        let name = typed.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, name != original else { return .unchanged }
        if name.contains("/") || name.contains(":") { return .invalid(ExplorerText.nameCantContainSeparators(languages)) }
        if name == "." || name == ".." { return .invalid(ExplorerText.invalidName(languages)) }
        if name.utf8.count > maxNameBytes { return .invalid(ExplorerText.nameTooLong(languages)) }
        if name.hasPrefix(".") && !original.hasPrefix(".") { return .confirmHidden(name) }
        if !isFolder {
            let from = (original as NSString).pathExtension, to = (name as NSString).pathExtension
            if !from.isEmpty && from.lowercased() != to.lowercased() {
                return .confirmExtensionChange(from: "." + from, to: to.isEmpty ? "" : "." + to)
            }
        }
        return .accept(name)
    }
}

public enum DropTarget: Equatable, Sendable {
    case folder(URL)
    case trash
}

public enum DropRules {
    /// nil = nothing to do: the destination is a source or inside one, or a move to where the items already are.
    public static func operation(sources: [URL], destination: URL, sameVolume: Bool,
                                 forceCopy: Bool, forceMove: Bool) -> FileOperationKind? {
        let target = destination.standardizedFileURL.path
        for source in sources {
            let path = source.standardizedFileURL.path
            if target == path || target.hasPrefix(path == "/" ? "/" : path + "/") { return nil }
        }
        let kind: FileOperationKind = forceCopy ? .copy : forceMove ? .move : (sameVolume ? .move : .copy)
        let alreadyThere = sources.allSatisfy { $0.standardizedFileURL.deletingLastPathComponent().path == target }
        return kind == .move && alreadyThere ? nil : kind
    }

    /// Where something dropped on `entry` (nil = the background of `location`) ends up.
    public static func target(entry: FileEntry?, at location: Location, home: URL, trash: URL) -> DropTarget? {
        if let entry {
            switch entry.kind {
            case .folder, .myDocuments, .volume: return .folder(entry.url)
            case .recycleBin: return .trash
            default: return nil
            }
        }
        switch location {
        case .desktop: return .folder(home.appending(path: "Desktop"))
        case .myComputer: return nil
        case .trash: return .trash
        case .folder(let url): return .folder(url)
        }
    }
}

extension FileEntry {
    /// A real file or folder; false for the places (My Computer, the My Documents shortcut, the Recycle Bin, volumes).
    public var isFileItem: Bool {
        switch kind {
        case .myComputer, .myDocuments, .recycleBin, .volume: false
        default: true
        }
    }
}
