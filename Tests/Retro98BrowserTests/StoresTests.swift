import Foundation
import Testing
@testable import Retro98Browser

private let a = web("https://a.example/"), b = web("https://b.example/")

@MainActor @Test func favoritesRoundTrip() throws {
    let folder = try temporaryFolder()
    defer { try? FileManager.default.removeItem(at: folder) }
    let file = folder.appending(path: "Browser/favorites.json")
    let store = FavoritesStore(file: file)
    #expect(store.add(title: "A", url: a))
    #expect(store.add(title: "B", url: b))
    #expect(store.isSaved)
    #expect(FavoritesStore(file: file).items == [Favorite(title: "A", url: a), Favorite(title: "B", url: b)])
}

@MainActor @Test func addingTheSameAddressTwiceKeepsOne() throws {
    let folder = try temporaryFolder()
    defer { try? FileManager.default.removeItem(at: folder) }
    let store = FavoritesStore(file: folder.appending(path: "favorites.json"))
    #expect(store.add(title: "A", url: a))
    #expect(!store.add(title: "Outra vez", url: a))
    #expect(store.items == [Favorite(title: "A", url: a)])
}

@MainActor @Test func moveRenameRemove() throws {
    let folder = try temporaryFolder()
    defer { try? FileManager.default.removeItem(at: folder) }
    let store = FavoritesStore(file: folder.appending(path: "favorites.json"))
    store.add(title: "A", url: a)
    store.add(title: "B", url: b)
    var changes = 0
    store.onChange = { changes += 1 }
    store.move(from: 0, to: 1)
    #expect(store.items.map(\.title) == ["B", "A"])
    store.rename(at: 0, to: "  ")
    #expect(store.items[0].title == "B")
    store.rename(at: 0, to: " Bê ")
    #expect(store.items[0].title == "Bê")
    store.move(from: 5, to: 0)
    store.move(from: 0, to: 9)
    store.rename(at: 7, to: "x")
    store.remove(at: -1)
    #expect(store.items.map(\.title) == ["Bê", "A"])
    #expect(changes == 2)
    store.remove(at: 0)
    #expect(store.items.map(\.title) == ["A"])
    #expect(FavoritesStore(file: folder.appending(path: "favorites.json")).items.map(\.title) == ["A"])
}

@MainActor @Test func damagedFavoritesAreKeptAside() throws {
    let folder = try temporaryFolder()
    defer { try? FileManager.default.removeItem(at: folder) }
    let file = folder.appending(path: "favorites.json")
    let damaged = Data("{not json".utf8)
    try damaged.write(to: file)
    let store = FavoritesStore(file: file)
    #expect(store.items.isEmpty)
    #expect(try Data(contentsOf: folder.appending(path: "favorites-damaged.json")) == damaged)
    store.add(title: "A", url: a)
    #expect(FavoritesStore(file: file).items == [Favorite(title: "A", url: a)])
    #expect(try Data(contentsOf: folder.appending(path: "favorites-damaged.json")) == damaged)
}

@MainActor @Test func unwritableFolderKeepsTheListInMemory() throws {
    let folder = try temporaryFolder()
    defer {
        try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: folder.path)
        try? FileManager.default.removeItem(at: folder)
    }
    try FileManager.default.setAttributes([.posixPermissions: 0o500], ofItemAtPath: folder.path)
    let store = FavoritesStore(file: folder.appending(path: "favorites.json"))
    #expect(store.add(title: "A", url: a))
    #expect(store.items.count == 1)
    #expect(!store.isSaved)
}

private func date(_ seconds: TimeInterval) -> Date { Date(timeIntervalSince1970: 1_800_000_000 + seconds) }

@MainActor @Test func historyNewestFirstOnePerAddress() throws {
    let folder = try temporaryFolder()
    defer { try? FileManager.default.removeItem(at: folder) }
    let file = folder.appending(path: "history.json")
    let store = HistoryStore(file: file)
    store.record(url: a, title: "A", at: date(1))
    store.record(url: b, title: "B", at: date(2))
    store.record(url: a, title: "A de novo", at: date(3))
    #expect(store.entries == [HistoryEntry(url: a, title: "A de novo", lastVisited: date(3)),
                              HistoryEntry(url: b, title: "B", lastVisited: date(2))])
    #expect(HistoryStore(file: file).entries == store.entries)
    store.setTitle("Bê", for: b)
    #expect(store.entries[1].title == "Bê")
}

@MainActor @Test func historyIgnoresOtherSchemes() throws {
    let folder = try temporaryFolder()
    defer { try? FileManager.default.removeItem(at: folder) }
    let store = HistoryStore(file: folder.appending(path: "history.json"))
    for text in ["about:blank", "retro98://home/", "data:text/plain,oi"] {
        store.record(url: web(text), title: "x", at: date(0))
    }
    #expect(store.entries.isEmpty)
    store.record(url: URL(filePath: "/tmp/a.html"), title: "arquivo", at: date(0))
    #expect(store.entries.count == 1)
}

@MainActor @Test func historyKeepsTheLimit() throws {
    let folder = try temporaryFolder()
    defer { try? FileManager.default.removeItem(at: folder) }
    let store = HistoryStore(file: folder.appending(path: "history.json"))
    for i in 0..<(HistoryStore.limit + 5) {
        store.record(url: web("https://example.com/\(i)"), title: "\(i)", at: date(TimeInterval(i)))
    }
    #expect(store.entries.count == 2000)
    #expect(store.entries.first?.title == "2004")
    #expect(store.entries.last?.title == "5")
}

@MainActor @Test func historySearchIgnoresCaseAndAccents() throws {
    let folder = try temporaryFolder()
    defer { try? FileManager.default.removeItem(at: folder) }
    let store = HistoryStore(file: folder.appending(path: "history.json"))
    store.record(url: a, title: "Pão de Queijo", at: date(1))
    store.record(url: web("https://example.com/Receita"), title: "Outra", at: date(2))
    #expect(store.search("pao").map(\.title) == ["Pão de Queijo"])
    #expect(store.search("receita").map(\.title) == ["Outra"])
    #expect(store.search(" ").count == 2)
    #expect(store.search("nada").isEmpty)
}

@MainActor @Test func historyRemoveAndClear() throws {
    let folder = try temporaryFolder()
    defer { try? FileManager.default.removeItem(at: folder) }
    let file = folder.appending(path: "history.json")
    let store = HistoryStore(file: file)
    store.record(url: a, title: "A", at: date(1))
    store.record(url: b, title: "B", at: date(2))
    store.remove(a)
    #expect(store.entries.map(\.url) == [b])
    store.clear()
    #expect(store.entries.isEmpty)
    #expect(HistoryStore(file: file).entries.isEmpty)
}

@MainActor @Test func damagedHistoryIsKeptAside() throws {
    let folder = try temporaryFolder()
    defer { try? FileManager.default.removeItem(at: folder) }
    let file = folder.appending(path: "history.json")
    try Data("[1, 2".utf8).write(to: file)
    #expect(HistoryStore(file: file).entries.isEmpty)
    #expect(FileManager.default.fileExists(atPath: folder.appending(path: "history-damaged.json").path))
}

@Test func homePageDefaultsToAboutHome() {
    #expect(BrowserPreferences.memory().homePage == "about:home")
}

@Test func homePageIsRemembered() {
    let preferences = BrowserPreferences.memory()
    preferences.homePage = "https://example.com/"
    #expect(preferences.homePage == "https://example.com/")
}
