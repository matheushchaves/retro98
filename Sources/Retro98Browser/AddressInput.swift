import Foundation

/// Where a typed address leads.
enum AddressTarget: Equatable, Sendable {
    /// The built-in home page.
    case home
    case url(URL)
}

/// Turns what was typed in the address bar into a destination: an address, a local file or a search.
enum AddressInput {
    static let searchPrefix = "https://duckduckgo.com/?q="
    static let homeText = "about:home"
    /// The built-in home page as the web view knows it; the address bar shows `homeText`.
    static let homeURL = URL(string: "retro98://home/")!
    private static let fullPrefixes = ["http://", "https://", "file://"]

    /// nil when there is nothing to open.
    static func resolve(_ text: String, home: URL) -> AddressTarget? {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        let lowercased = text.lowercased()
        if lowercased == homeText { return .home }
        if lowercased == "about:blank", let blank = URL(string: "about:blank") { return .url(blank) }
        if fullPrefixes.contains(where: lowercased.hasPrefix), let url = URL(string: text) { return .url(url) }
        if text.hasPrefix("/") { return .url(URL(filePath: text)) }
        if text == "~" { return .url(home) }
        if text.hasPrefix("~/") { return .url(home.appending(path: String(text.dropFirst(2)))) }
        if let url = address(text) { return .url(url) }
        return search(text).map(AddressTarget.url)
    }

    /// What the address bar shows for a page.
    static func display(_ url: URL?) -> String {
        guard let url else { return "" }
        return isHome(url) ? homeText : url.absoluteString
    }

    static func isHome(_ url: URL) -> Bool {
        url.scheme?.lowercased() == homeURL.scheme && url.host() == homeURL.host()
    }

    /// The text as a web address when it looks like one: no spaces, and a server name with a dot, a port or "localhost".
    private static func address(_ text: String) -> URL? {
        guard !text.contains(where: \.isWhitespace), let probe = URL(string: "https://" + text),
              let host = probe.host()?.lowercased(), !host.isEmpty else { return nil }
        // Reached without encryption: this Mac, numeric addresses and names on the local network.
        let isLocal = host == "localhost" || host.hasSuffix(".local") || isIPv4(host)
        guard isLocal || host.contains(".") || probe.port != nil else { return nil }
        return isLocal ? URL(string: "http://" + text) : probe
    }

    private static func isIPv4(_ host: String) -> Bool {
        let parts = host.split(separator: ".", omittingEmptySubsequences: false)
        return parts.count == 4 && parts.allSatisfy { !$0.isEmpty && $0.count <= 3 && $0.allSatisfy(\.isNumber) }
    }

    private static func search(_ text: String) -> URL? {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        guard let query = text.addingPercentEncoding(withAllowedCharacters: allowed) else { return nil }
        return URL(string: searchPrefix + query)
    }
}
