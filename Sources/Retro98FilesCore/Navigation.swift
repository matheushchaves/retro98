import Foundation
import Retro98Settings

public struct NavigationHistory: Equatable, Sendable {
    public private(set) var current: Location
    private var backStack: [Location] = []
    private var forwardStack: [Location] = []

    public init(start: Location) {
        current = start
    }

    public var canGoBack: Bool { !backStack.isEmpty }
    public var canGoForward: Bool { !forwardStack.isEmpty }

    /// Going somewhere new clears the forward list; going to the current place does nothing.
    public mutating func go(to location: Location) {
        guard location != current else { return }
        backStack.append(current)
        forwardStack.removeAll()
        current = location
    }

    public mutating func back() {
        guard let previous = backStack.popLast() else { return }
        forwardStack.append(current)
        current = previous
    }

    public mutating func forward() {
        guard let next = forwardStack.popLast() else { return }
        backStack.append(current)
        current = next
    }

    /// Stands in for a place that vanished, without adding it to Back.
    public mutating func replaceCurrent(with location: Location) {
        current = location
    }

    /// Folder → its parent folder; a volume's root → My Computer; My Computer and the Recycle Bin → Desktop.
    public static func parent(of location: Location, volumes: [URL]) -> Location? {
        switch location {
        case .desktop: return nil
        case .myComputer, .trash: return .desktop
        case .folder(let url):
            let path = url.path
            if path == "/" || volumes.contains(where: { $0.path == path }) { return .myComputer }
            return .folder(URL(filePath: (path as NSString).deletingLastPathComponent))
        }
    }

    /// `location`, its parent, and so on up to the Desktop (the address bar's drop-down list).
    public static func ancestors(of location: Location, volumes: [URL]) -> [Location] {
        var chain = [location]
        while let parent = parent(of: chain[chain.count - 1], volumes: volumes) { chain.append(parent) }
        return chain
    }

    /// For a place that no longer exists: the nearest existing ancestor folder, or My Computer.
    public static func recover(_ location: Location, exists: (URL) -> Bool, volumes: [URL]) -> Location {
        guard case .folder(var url) = location else { return location }
        var isStart = true
        while true {
            // Walking up out of an ejected drive reaches /Volumes, a hidden system folder: show My Computer.
            if !isStart && url.path == "/Volumes" { return .myComputer }
            isStart = false
            if exists(url) { return .folder(url) }
            guard let parent = parent(of: .folder(url), volumes: volumes) else { return .desktop }
            guard case .folder(let next) = parent else { return parent }
            url = next
        }
    }
}

public enum AddressParser {
    static let desktopNames = ["área de trabalho", "desktop"]
    static let myComputerNames = ["meu computador", "my computer"]
    static let trashNames = ["lixeira", "recycle bin", "trash"]

    public static func location(for text: String, home: URL, languages: [String], isDirectory: (String) -> Bool) -> Location? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let matches = { (names: [String]) in
            names.contains { trimmed.compare($0, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame }
        }
        if matches(desktopNames) { return .desktop }
        if matches(myComputerNames) { return .myComputer }
        if matches(trashNames) { return .trash }
        var path = trimmed
        if path == "~" || path.hasPrefix("~/") { path = home.path + path.dropFirst() }
        guard path.hasPrefix("/") else { return nil }
        while path.count > 1 && path.hasSuffix("/") { path.removeLast() }
        return isDirectory(path) ? .folder(URL(filePath: path)) : nil
    }

    public static func text(for location: Location, languages: [String]) -> String {
        switch location {
        case .desktop: ExplorerText.desktop(languages)
        case .myComputer: ExplorerText.myComputer(languages)
        case .trash: ExplorerText.recycleBin(languages)
        case .folder(let url): url.path
        }
    }
}

public enum StatusText {
    public static func objects(count: Int, selected: Int, languages: [String]) -> String {
        selected > 0
            ? LocalizedText(en: "\(selected) object(s) selected", ptBR: "\(selected) objeto(s) selecionado(s)").resolve(for: languages)
            : LocalizedText(en: "\(count) object(s)", ptBR: "\(count) objeto(s)").resolve(for: languages)
    }

    /// Finder-style decimal sizes ("1,2 MB", "190 GB") in the given locale.
    public static func bytes(_ value: Int64, locale: Locale) -> String {
        guard value >= 1000 else { return "\(value) bytes" }
        let units = ["KB", "MB", "GB", "TB"]
        var amount = Double(value) / 1000
        var unit = 0
        while amount >= 1000 && unit < units.count - 1 {
            amount /= 1000
            unit += 1
        }
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.maximumFractionDigits = amount < 100 ? 1 : 0
        formatter.minimumFractionDigits = 0
        return "\(formatter.string(from: NSNumber(value: amount)) ?? "\(amount)") \(units[unit])"
    }

    public static func free(_ value: Int64, locale: Locale, languages: [String]) -> String {
        LocalizedText(en: "Free: ", ptBR: "Livre: ").resolve(for: languages) + bytes(value, locale: locale)
    }
}

/// What a `retro98-explorer://` link asks for: a window on a place, or a window that searches (nil = the home folder).
public enum ExplorerRequest: Equatable, Sendable {
    case open(Location)
    case search(Location?)
}

public enum ExplorerURL {
    public static let scheme = "retro98-explorer"

    /// `retro98-explorer://search`, or `…/search?path=<folder>` to search a given folder.
    public static func searchURL(in location: Location?) -> URL {
        var components = URLComponents()
        components.scheme = scheme
        components.host = "search"
        if case .folder(let url)? = location { components.queryItems = [URLQueryItem(name: "path", value: url.path)] }
        return components.url!
    }

    public static func request(from url: URL) -> ExplorerRequest? {
        if let location = location(from: url) { return .open(location) }
        guard url.scheme == scheme, let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.host == "search" else { return nil }
        guard let path = components.queryItems?.first(where: { $0.name == "path" })?.value, path.hasPrefix("/") else { return .search(nil) }
        return .search(.folder(URL(filePath: path)))
    }

    public static func url(for location: Location) -> URL {
        var components = URLComponents()
        components.scheme = scheme
        switch location {
        case .desktop: components.host = "desktop"
        case .myComputer: components.host = "my-computer"
        case .trash: components.host = "trash"
        case .folder(let url):
            components.host = "folder"
            components.queryItems = [URLQueryItem(name: "path", value: url.path)]
        }
        return components.url!
    }

    public static func location(from url: URL) -> Location? {
        guard url.scheme == scheme, let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        switch components.host {
        case "desktop": return .desktop
        case "my-computer": return .myComputer
        case "trash": return .trash
        case "folder":
            guard let path = components.queryItems?.first(where: { $0.name == "path" })?.value, path.hasPrefix("/") else { return nil }
            return .folder(URL(filePath: path))
        default: return nil
        }
    }
}
