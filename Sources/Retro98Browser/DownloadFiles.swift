import Foundation

/// File names for downloads: never a path, never a name already in use.
enum DownloadNames {
    static let fallback = "download"
    static let partExtension = "download"

    /// The server's suggestion as a plain file name: its last component, no control characters, ":" as "-",
    /// no leading dots (so nothing arrives hidden).
    static func clean(_ suggested: String) -> String {
        let last = suggested.split(whereSeparator: { $0 == "/" || $0 == "\\" }).last.map(String.init) ?? ""
        let scalars = last.unicodeScalars.filter { $0.value >= 0x20 && $0.value != 0x7F }
        var name = String(String.UnicodeScalarView(scalars)).replacingOccurrences(of: ":", with: "-")
        name = name.trimmingCharacters(in: .whitespaces)
        name = String(name.drop { $0 == "." })
        return name.isEmpty ? fallback : name
    }

    /// `name` if nothing in `folder` has it (as a file or as "<name>.download"), else "stem (2).ext", "stem (3).ext"…
    /// `inFlight` lists part files that are spoken for but not on disk yet; `ignoring` is a part file that doesn't count.
    static func free(_ name: String, in folder: URL, inFlight: Set<String> = [], ignoring: String? = nil,
                     fileManager: FileManager = .default) -> String {
        func isTaken(_ candidate: String) -> Bool {
            let part = candidate + "." + partExtension
            if fileManager.fileExists(atPath: folder.appending(path: candidate).path) { return true }
            if part == ignoring { return false }
            return inFlight.contains(part) || fileManager.fileExists(atPath: folder.appending(path: part).path)
        }
        guard isTaken(name) else { return name }
        let ext = (name as NSString).pathExtension, stem = (name as NSString).deletingPathExtension
        var number = 2
        while true {
            let candidate = ext.isEmpty ? "\(stem) (\(number))" : "\(stem) (\(number)).\(ext)"
            if !isTaken(candidate) { return candidate }
            number += 1
        }
    }
}

/// One download's file: written as "<name>.download", moved to a free final name when done.
struct DownloadFile: Equatable {
    let folder: URL
    /// The clean name the download asked for.
    let name: String
    let partURL: URL

    init(suggestedName: String, folder: URL, inFlight: Set<String> = [], fileManager: FileManager = .default) {
        self.folder = folder
        name = DownloadNames.clean(suggestedName)
        let reserved = DownloadNames.free(name, in: folder, inFlight: inFlight, fileManager: fileManager)
        partURL = folder.appending(path: reserved + "." + DownloadNames.partExtension)
    }

    /// Moves the finished file to its final name, which is chosen now and never replaces a file.
    func finish(fileManager: FileManager = .default) throws -> URL {
        let finalName = DownloadNames.free(name, in: folder, ignoring: partURL.lastPathComponent, fileManager: fileManager)
        let final = folder.appending(path: finalName)
        try fileManager.moveItem(at: partURL, to: final)
        return final
    }

    func discard(fileManager: FileManager = .default) {
        try? fileManager.removeItem(at: partURL)
    }
}
