import Foundation

struct HistoryEntry: Codable, Equatable, Sendable {
    var url: URL
    var title: String
    var lastVisited: Date
}

/// The pages visited, newest first, one entry per address, written to its file at every change.
@MainActor
final class HistoryStore {
    static let limit = 2000
    /// Built-in pages and one-off addresses (about:, data:) are not history.
    static let recordedSchemes: Set<String> = ["http", "https", "file"]

    private(set) var entries: [HistoryEntry]
    var onChange: (() -> Void)?
    private let storage: BrowserStorage<[HistoryEntry]>

    init(file: URL) {
        storage = BrowserStorage(file: file)
        entries = storage.load() ?? []
    }

    func record(url: URL, title: String, at date: Date) {
        guard let scheme = url.scheme?.lowercased(), Self.recordedSchemes.contains(scheme) else { return }
        entries.removeAll { $0.url.absoluteString == url.absoluteString }
        entries.insert(HistoryEntry(url: url, title: title, lastVisited: date), at: 0)
        if entries.count > Self.limit { entries.removeLast(entries.count - Self.limit) }
        changed()
    }

    func setTitle(_ title: String, for url: URL) {
        guard let index = entries.firstIndex(where: { $0.url.absoluteString == url.absoluteString }),
              entries[index].title != title else { return }
        entries[index].title = title
        changed()
    }

    /// Entries whose title or address has the text, ignoring case and accents; a blank text gives all.
    func search(_ text: String) -> [HistoryEntry] {
        let needle = Self.folded(text.trimmingCharacters(in: .whitespacesAndNewlines))
        guard !needle.isEmpty else { return entries }
        return entries.filter { Self.folded($0.title).contains(needle) || Self.folded($0.url.absoluteString).contains(needle) }
    }

    func remove(_ url: URL) {
        let count = entries.count
        entries.removeAll { $0.url.absoluteString == url.absoluteString }
        if entries.count != count { changed() }
    }

    func clear() {
        entries = []
        changed()
    }

    private static func folded(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
    }

    private func changed() {
        try? storage.save(entries)
        onChange?()
    }
}
