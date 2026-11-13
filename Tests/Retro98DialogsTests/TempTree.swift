import Foundation

/// A throwaway folder tree; paths ending in ".app" become empty app bundles.
final class TempTree {
    let root: URL

    init(_ paths: [String]) throws {
        root = FileManager.default.temporaryDirectory.appending(path: "retro98-\(UUID().uuidString)", directoryHint: .isDirectory)
        for path in paths {
            let url = root.appending(path: path)
            if path.hasSuffix(".txt") {
                try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                try Data().write(to: url)
            } else {
                try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            }
        }
    }

    func url(_ path: String) -> URL { root.appending(path: path, directoryHint: .notDirectory) }

    deinit { try? FileManager.default.removeItem(at: root) }
}
