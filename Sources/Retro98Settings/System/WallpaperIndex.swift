import Foundation

/// Reads the wallpaper agent's store (Index.plist), a property list whose choices carry
/// their configuration as nested property lists.
enum WallpaperIndex {
    /// Whether any choice in the store shows one of Retro98's own wallpaper images.
    static func showsRetro98Image(_ index: Data, paths: Retro98Paths) -> Bool {
        strings(in: index).contains { isRetro98Image($0, paths: paths) }
    }

    private static func strings(in data: Data) -> [String] {
        guard let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) else { return [] }
        return strings(inValue: plist)
    }

    private static func strings(inValue value: Any) -> [String] {
        switch value {
        case let string as String: [string]
        case let data as Data: strings(in: data)
        case let array as [Any]: array.flatMap(strings(inValue:))
        case let dictionary as [String: Any]: dictionary.values.flatMap(strings(inValue:))
        default: []
        }
    }

    private static func isRetro98Image(_ string: String, paths: Retro98Paths) -> Bool {
        guard let url = string.hasPrefix("/") ? URL(filePath: string) : URL(string: string), url.isFileURL else { return false }
        return url.lastPathComponent.hasPrefix("wallpaper-")
            && url.deletingLastPathComponent().standardizedFileURL.path == paths.supportDirectory.standardizedFileURL.path
    }
}
