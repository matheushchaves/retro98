import Foundation
import Testing
@testable import Retro98Browser

@MainActor final class FakeTransfer: DownloadTransfer {
    var received: Int64 = 0
    var total: Int64?
    private(set) var cancels = 0

    func cancel(_ done: @escaping @MainActor @Sendable () -> Void) {
        cancels += 1
        done()
    }
}

@MainActor private final class Downloads {
    let folder: URL
    let prompter = ScriptedBrowserPrompter()
    let center: DownloadCenter
    var finished: [String] = []

    init() throws {
        folder = try temporaryFolder()
        center = DownloadCenter(folder: folder, prompter: prompter, languages: ["pt-BR"], locale: Locale(identifier: "pt_BR"))
        center.presentsDialogs = false
        center.onFinish = { [unowned self] in finished.append($0) }
    }

    var files: [String] { ((try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []).sorted() }
    func cleanUp() { try? FileManager.default.removeItem(at: folder) }
}

@MainActor @Test func beginReturnsAPartFileInTheFolder() throws {
    let downloads = try Downloads()
    defer { downloads.cleanUp() }
    let part = downloads.center.begin(FakeTransfer(), suggestedName: "a.zip", host: "example.com")
    #expect(part == downloads.folder.appending(path: "a.zip.download"))
    #expect(downloads.center.activeCount == 1)
    #expect(!FileManager.default.fileExists(atPath: part.path))
}

@MainActor @Test func beginCreatesTheFolderWhenMissing() throws {
    let downloads = try Downloads()
    defer { downloads.cleanUp() }
    let center = DownloadCenter(folder: downloads.folder.appending(path: "Downloads"), prompter: downloads.prompter, languages: ["en"])
    center.presentsDialogs = false
    _ = center.begin(FakeTransfer(), suggestedName: "a.zip", host: "")
    #expect(downloads.files == ["Downloads"])
}

@MainActor @Test func hostileNamesStayInTheFolder() throws {
    let downloads = try Downloads()
    defer { downloads.cleanUp() }
    let part = downloads.center.begin(FakeTransfer(), suggestedName: "../../etc/passwd", host: "example.com")
    #expect(part == downloads.folder.appending(path: "passwd.download"))
}

@MainActor @Test func finishMovesTheFileAndTellsTheWindows() throws {
    let downloads = try Downloads()
    defer { downloads.cleanUp() }
    let transfer = FakeTransfer()
    let part = downloads.center.begin(transfer, suggestedName: "a.zip", host: "example.com")
    try Data("zip".utf8).write(to: part)
    downloads.center.finished(transfer)
    #expect(downloads.files == ["a.zip"])
    #expect(downloads.finished == ["a.zip"])
    #expect(downloads.center.activeCount == 0)
    #expect(downloads.prompter.told.isEmpty)
}

@MainActor @Test func finishNeverReplacesAnExistingFile() throws {
    let downloads = try Downloads()
    defer { downloads.cleanUp() }
    try Data("antigo".utf8).write(to: downloads.folder.appending(path: "a.zip"))
    let transfer = FakeTransfer()
    let part = downloads.center.begin(transfer, suggestedName: "a.zip", host: "example.com")
    #expect(part.lastPathComponent == "a (2).zip.download")
    try Data("novo".utf8).write(to: part)
    downloads.center.finished(transfer)
    #expect(downloads.files == ["a (2).zip", "a.zip"])
    #expect(try String(contentsOf: downloads.folder.appending(path: "a.zip"), encoding: .utf8) == "antigo")
    #expect(downloads.finished == ["a (2).zip"])
}

@MainActor @Test func twoDownloadsOfOneNameAtOnceBothArrive() throws {
    let downloads = try Downloads()
    defer { downloads.cleanUp() }
    let first = FakeTransfer(), second = FakeTransfer()
    let firstPart = downloads.center.begin(first, suggestedName: "a.zip", host: "example.com")
    let secondPart = downloads.center.begin(second, suggestedName: "a.zip", host: "example.com")
    #expect(firstPart != secondPart)
    try Data("1".utf8).write(to: firstPart)
    try Data("2".utf8).write(to: secondPart)
    downloads.center.finished(second)
    downloads.center.finished(first)
    #expect(downloads.files.count == 2)
    #expect(Set(downloads.files.map { try? String(contentsOf: downloads.folder.appending(path: $0), encoding: .utf8) }) == ["1", "2"])
}

@MainActor @Test func cancelRemovesThePartAndCancelsTheTransfer() throws {
    let downloads = try Downloads()
    defer { downloads.cleanUp() }
    let transfer = FakeTransfer()
    let part = downloads.center.begin(transfer, suggestedName: "a.zip", host: "example.com")
    try Data("meio".utf8).write(to: part)
    downloads.center.cancel(transfer)
    #expect(transfer.cancels == 1)
    #expect(downloads.files.isEmpty)
    #expect(downloads.center.activeCount == 0)
    #expect(downloads.finished.isEmpty)
    // WebKit reports the cancelled download as failed afterwards: nothing more happens.
    downloads.center.failed(transfer, message: "cancelado")
    #expect(downloads.prompter.told.isEmpty)
}

@MainActor @Test func failureRemovesThePartAndTells() throws {
    let downloads = try Downloads()
    defer { downloads.cleanUp() }
    let transfer = FakeTransfer()
    let part = downloads.center.begin(transfer, suggestedName: "a.zip", host: "example.com")
    try Data("meio".utf8).write(to: part)
    downloads.center.failed(transfer, message: "sem conexão")
    #expect(downloads.files.isEmpty)
    #expect(downloads.center.activeCount == 0)
    #expect(downloads.prompter.told.count == 1)
    #expect(downloads.prompter.told[0].contains("a.zip") && downloads.prompter.told[0].contains("sem conexão"))
}

@MainActor @Test func finishThatCannotMoveIsAFailure() throws {
    let downloads = try Downloads()
    defer { downloads.cleanUp() }
    let transfer = FakeTransfer()
    _ = downloads.center.begin(transfer, suggestedName: "a.zip", host: "example.com")
    downloads.center.finished(transfer)
    #expect(downloads.prompter.told.count == 1 && downloads.prompter.told[0].contains("a.zip"))
    #expect(downloads.center.activeCount == 0)
    #expect(downloads.finished.isEmpty)
}

@MainActor @Test func cancelAllLeavesNoPartFiles() throws {
    let downloads = try Downloads()
    defer { downloads.cleanUp() }
    let first = FakeTransfer(), second = FakeTransfer()
    try Data("1".utf8).write(to: downloads.center.begin(first, suggestedName: "a.zip", host: "x"))
    try Data("2".utf8).write(to: downloads.center.begin(second, suggestedName: "b.zip", host: "x"))
    downloads.center.cancelAll()
    #expect(first.cancels == 1 && second.cancels == 1)
    #expect(downloads.files.isEmpty)
    #expect(downloads.center.activeCount == 0)
}

@MainActor @Test func linesShowReceivedAndTotal() throws {
    let downloads = try Downloads()
    defer { downloads.cleanUp() }
    let transfer = FakeTransfer()
    _ = downloads.center.begin(transfer, suggestedName: "a.zip", host: "example.com")
    transfer.received = 1_536
    transfer.total = 4_096
    downloads.center.progressed(transfer)
    let known = try #require(downloads.center.lines(for: transfer))
    #expect(known.item == "Salvando: a.zip de example.com")
    #expect(known.detail.contains(" de ") && known.detail.contains("KB"))
    #expect(known.fraction == 0.375)
    transfer.total = nil
    let unknown = try #require(downloads.center.lines(for: transfer))
    #expect(!unknown.detail.contains(" de "))
    #expect(unknown.fraction == 0)
    transfer.total = 100
    transfer.received = 500
    #expect(downloads.center.lines(for: transfer)?.fraction == 1)
}

@MainActor @Test func hostileHostIsOneShortLine() throws {
    let downloads = try Downloads()
    defer { downloads.cleanUp() }
    let transfer = FakeTransfer()
    _ = downloads.center.begin(transfer, suggestedName: "a.zip", host: String(repeating: "h\n", count: 500))
    let lines = try #require(downloads.center.lines(for: transfer))
    #expect(!lines.item.contains("\n") && lines.item.count < 200)
}

@MainActor @Test func eventsForAnUnknownTransferAreIgnored() throws {
    let downloads = try Downloads()
    defer { downloads.cleanUp() }
    let stranger = FakeTransfer()
    downloads.center.progressed(stranger)
    downloads.center.finished(stranger)
    downloads.center.failed(stranger, message: "x")
    downloads.center.cancel(stranger)
    #expect(downloads.center.lines(for: stranger) == nil)
    #expect(downloads.prompter.told.isEmpty && downloads.finished.isEmpty && stranger.cancels == 0)
}

// MARK: Review fixes

@MainActor @Test func finishedFileThatCannotBeMovedIsKept() throws {
    let downloads = try Downloads()
    defer {
        try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: downloads.folder.path)
        downloads.cleanUp()
    }
    let transfer = FakeTransfer()
    let part = downloads.center.begin(transfer, suggestedName: "a.zip", host: "example.com")
    try Data("completo".utf8).write(to: part)
    try FileManager.default.setAttributes([.posixPermissions: 0o500], ofItemAtPath: downloads.folder.path)
    downloads.center.finished(transfer)
    try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: downloads.folder.path)
    #expect(try String(contentsOf: part, encoding: .utf8) == "completo")
    #expect(downloads.prompter.told.count == 1 && downloads.prompter.told[0].contains("a.zip.download"))
    #expect(downloads.center.activeCount == 0 && downloads.finished.isEmpty)
}
