import Foundation

struct Favorite: Codable, Equatable, Sendable {
    var title: String
    var url: URL
}

/// The person's favorites: one ordered list, written to its file at every change.
@MainActor
final class FavoritesStore {
    private(set) var items: [Favorite]
    var onChange: (() -> Void)?
    /// False when the last change could not be written (the list in memory still has it).
    private(set) var isSaved = true
    /// A change could not be written; called once each time saving starts to fail.
    var onSaveFailure: (() -> Void)?
    /// Where a file that couldn't be read was kept at launch, if that happened.
    let damagedCopy: URL?
    private let storage: BrowserStorage<[Favorite]>

    init(file: URL) {
        storage = BrowserStorage(file: file)
        let loaded = storage.loadReportingDamage()
        items = loaded.value ?? []
        damagedCopy = loaded.damagedCopy
    }

    /// False when the address is already a favorite.
    @discardableResult
    func add(title: String, url: URL) -> Bool {
        guard !items.contains(where: { $0.url.absoluteString == url.absoluteString }) else { return false }
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        items.append(Favorite(title: title.isEmpty ? url.absoluteString : title, url: url))
        changed()
        return true
    }

    func remove(at index: Int) {
        guard items.indices.contains(index) else { return }
        items.remove(at: index)
        changed()
    }

    func move(from index: Int, to destination: Int) {
        guard items.indices.contains(index), items.indices.contains(destination), index != destination else { return }
        items.insert(items.remove(at: index), at: destination)
        changed()
    }

    /// Blank titles are ignored.
    func rename(at index: Int, to title: String) {
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard items.indices.contains(index), !title.isEmpty, items[index].title != title else { return }
        items[index].title = title
        changed()
    }

    private func changed() {
        let wasSaved = isSaved
        isSaved = (try? storage.save(items)) != nil
        if wasSaved, !isSaved { onSaveFailure?() }
        onChange?()
    }
}
