import Foundation

public indirect enum ProgramNode: Equatable, Sendable {
    case folder(name: String, children: [ProgramNode])
    /// `name` is the display name without ".app".
    case app(name: String, url: URL)

    var name: String {
        switch self {
        case .folder(let name, _), .app(let name, _): name
        }
    }

    var isFolder: Bool {
        if case .folder = self { return true }
        return false
    }
}

/// Builds the Start menu's Programs tree from application folders.
public enum ProgramsTreeBuilder {
    /// Guards against symlink cycles and absurdly deep folders.
    static let maxDepth = 5

    public static let standardRoots: @Sendable (URL) -> [URL] = { home in
        [URL(filePath: "/Applications"), URL(filePath: "/System/Applications"), home.appending(path: "Applications")]
    }

    /// Merges the roots in order (same-named folders merge, the first same-named app wins),
    /// skips what can't be read, drops folders without apps and sorts folders first, then by name.
    public static func build(roots: [URL], fileManager: FileManager = .default) -> [ProgramNode] {
        let merged = roots.map { scan($0, depth: 0, fileManager: fileManager) }.reduce([], merge)
        return pruneAndSort(merged)
    }

    private static func scan(_ folder: URL, depth: Int, fileManager: FileManager) -> [ProgramNode] {
        guard depth < maxDepth, let names = try? fileManager.contentsOfDirectory(atPath: folder.path) else { return [] }
        return names.filter { !$0.hasPrefix(".") }.compactMap { name in
            let url = folder.appending(path: name, directoryHint: .notDirectory)
            if name.lowercased().hasSuffix(".app") {
                return .app(name: displayName(url, fileManager: fileManager), url: url)
            }
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue else { return nil }
            return .folder(name: displayName(url, fileManager: fileManager),
                           children: scan(url, depth: depth + 1, fileManager: fileManager))
        }
    }

    private static func merge(_ existing: [ProgramNode], _ incoming: [ProgramNode]) -> [ProgramNode] {
        incoming.reduce(existing) { result, node in
            guard let index = result.firstIndex(where: { $0.name == node.name && $0.isFolder == node.isFolder }) else {
                return result + [node]
            }
            guard case .folder(let name, let current) = result[index], case .folder(_, let extra) = node else {
                return result   // same-named app: keep the first one
            }
            var updated = result
            updated[index] = .folder(name: name, children: merge(current, extra))
            return updated
        }
    }

    private static func pruneAndSort(_ nodes: [ProgramNode]) -> [ProgramNode] {
        nodes.compactMap { node -> ProgramNode? in
            guard case .folder(let name, let children) = node else { return node }
            let kept = pruneAndSort(children)
            return kept.isEmpty ? nil : .folder(name: name, children: kept)
        }
        .sorted { lhs, rhs in
            if lhs.isFolder != rhs.isFolder { return lhs.isFolder }
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }
    }

    private static func displayName(_ url: URL, fileManager: FileManager) -> String {
        let name = fileManager.displayName(atPath: url.path)
        return name.lowercased().hasSuffix(".app") ? String(name.dropLast(4)) : name
    }
}
