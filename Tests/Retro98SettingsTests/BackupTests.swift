import Foundation
import Testing
@testable import Retro98Settings

private let backupURL = URL(filePath: "/support/backup.plist")

private func sampleBackup() -> Backup {
    Backup.empty
        .recording(PreferenceBackupEntry(tweak: .lightAppearance, key: styleKey, original: nil))
        .recording(PreferenceBackupEntry(
            tweak: .pointer,
            key: PreferenceKey(domain: .app("com.apple.universalaccess"), name: "cursorFill"),
            original: .dictionary(["alpha": .int(1), "red": .double(0.99)])
        ))
        .recording(FileBackupEntry(tweak: .wallpaper, path: "/x/Index.plist", original: Data("aerials".utf8)))
}

@Test func keepsEarliestOriginal() {
    let backup = Backup.empty
        .recording(PreferenceBackupEntry(tweak: .lightAppearance, key: styleKey, original: .string("Dark")))
        .recording(PreferenceBackupEntry(tweak: .lightAppearance, key: styleKey, original: nil))
    #expect(backup.preferences.map(\.original) == [.string("Dark")])
}

@Test func keepsEarliestFileOriginal() {
    let backup = Backup.empty
        .recording(FileBackupEntry(tweak: .wallpaper, path: "/x", original: Data("first".utf8)))
        .recording(FileBackupEntry(tweak: .wallpaper, path: "/x", original: Data("second".utf8)))
    #expect(backup.files.map(\.original) == [Data("first".utf8)])
}

@Test func removingTweaksDropsTheirEntries() {
    let backup = sampleBackup().removing(tweaks: [.pointer, .wallpaper])
    #expect(backup.tweakIDs == [.lightAppearance])
    #expect(backup.files.isEmpty)
    #expect(!backup.isEmpty)
    #expect(backup.removing(tweaks: [.lightAppearance]).isEmpty)
}

@Test func missingFileLoadsEmpty() throws {
    #expect(try BackupFile(url: backupURL, files: InMemoryFileStore()).load() == .empty)
}

@Test func savesAndLoadsRoundTrip() throws {
    let file = BackupFile(url: backupURL, files: InMemoryFileStore())
    try file.save(sampleBackup())
    #expect(try file.load() == sampleBackup())
}

@Test func savesHumanReadableXML() throws {
    let files = InMemoryFileStore()
    try BackupFile(url: backupURL, files: files).save(sampleBackup())
    let text = String(decoding: try #require(files.snapshot[backupURL]), as: UTF8.self)
    #expect(text.hasPrefix("<?xml"))
}

@Test func savingEmptyBackupDeletesFile() throws {
    let files = InMemoryFileStore()
    let file = BackupFile(url: backupURL, files: files)
    try file.save(sampleBackup())
    try file.save(.empty)
    #expect(files.snapshot[backupURL] == nil)
}

@Test func corruptedFileThrowsAndIsLeftUntouched() throws {
    let garbage = Data("not a plist".utf8)
    let files = InMemoryFileStore([backupURL: garbage])
    #expect(throws: BackupError.self) { try BackupFile(url: backupURL, files: files).load() }
    #expect(files.snapshot[backupURL] == garbage)
}

@Test func newerVersionThrowsUnsupportedVersion() throws {
    let encoder = PropertyListEncoder()
    let future = Backup(version: 2, preferences: [], files: [])
    let files = InMemoryFileStore([backupURL: try encoder.encode(future)])
    #expect(throws: BackupError.unsupportedVersion(2)) { try BackupFile(url: backupURL, files: files).load() }
}

@Test func localFileStoreWritesAtomicallyAndDeletes() throws {
    let root = FileManager.default.temporaryDirectory.appending(path: "retro98-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: root) }
    let url = root.appending(path: "nested/dir/file.bin")
    let store = LocalFileStore()

    #expect(try store.read(url) == nil)
    try store.write(Data([7]), to: url)
    #expect(try store.read(url) == Data([7]))
    try store.write(nil, to: url)
    #expect(try store.read(url) == nil)
    try store.write(nil, to: url)
}
