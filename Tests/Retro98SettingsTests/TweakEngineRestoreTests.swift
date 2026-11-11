import Foundation
import Testing
@testable import Retro98Settings

@Test func applyThenRestoreReturnsExactOriginalState() throws {
    let fixture = EngineFixture()
    _ = try fixture.engine.apply()
    let report = try fixture.engine.restore()

    #expect(report.failed.isEmpty)
    #expect(Set(report.succeeded) == Set(TweakID.allCases))
    #expect(fixture.store.snapshot == machineLikePreferences)
    #expect(fixture.files.snapshot[indexURL] == originalIndex)
    #expect(fixture.files.snapshot[fixtureBackupURL] == nil)
}

@Test func restorePreservesOriginalValueTypes() throws {
    let preferences = machineLikePreferences.merging([autoSwitchKey: .int(1)]) { _, new in new }
    let fixture = EngineFixture(preferences: preferences)
    _ = try fixture.engine.apply()
    _ = try fixture.engine.restore()

    #expect(fixture.store.value(for: autoSwitchKey) == .int(1))
    #expect(fixture.store.value(for: cursorOutlineKey) == initialCursorOutline)
}

@Test func restoreSubsetLeavesOthersApplied() throws {
    let fixture = EngineFixture()
    _ = try fixture.engine.apply()
    let report = try fixture.engine.restore([.colors])

    #expect(report.succeeded == [.colors])
    #expect(fixture.store.value(for: accentKey) == nil)
    #expect(fixture.store.value(for: scrollBarsKey) == .string("Always"))
    let remaining = try fixture.backupFile.load().tweakIDs
    #expect(!remaining.contains(.colors))
    #expect(remaining.contains(.scrollBars))
}

@Test func failedRestoreKeepsBackupEntries() throws {
    let fixture = EngineFixture()
    _ = try fixture.engine.apply()
    fixture.store.deniedKeys = [increaseContrastKey]
    let report = try fixture.engine.restore()

    #expect(report.failed.map(\.id) == [.contrast])
    #expect(try fixture.backupFile.load().tweakIDs == [.contrast])
}

@Test func corruptedBackupMakesRestoreThrowAndChangeNothing() throws {
    let fixture = EngineFixture()
    _ = try fixture.engine.apply()
    let applied = fixture.store.snapshot
    try fixture.files.write(Data("garbage".utf8), to: fixtureBackupURL)

    #expect(throws: BackupError.self) { try fixture.engine.restore() }
    #expect(fixture.store.snapshot == applied)
    #expect(fixture.files.snapshot[fixtureBackupURL] == Data("garbage".utf8))
}

@Test func restoreWithoutBackupIsANoOp() throws {
    let fixture = EngineFixture()
    let report = try fixture.engine.restore()

    #expect(report == EngineReport(succeeded: [], failed: [], warnings: []))
    #expect(fixture.log.events.isEmpty)
}

@Test func restoringWallpaperRewritesIndexAndRestartsAgent() throws {
    let fixture = EngineFixture()
    _ = try fixture.engine.apply([.wallpaper])
    try fixture.files.write(Data("teal".utf8), to: indexURL)
    fixture.log.events.removeAll()

    _ = try fixture.engine.restore([.wallpaper])

    #expect(fixture.files.snapshot[indexURL] == originalIndex)
    #expect(fixture.refresher.calls == ["perform(restartWallpaperAgent)"])
}

@Test func restoringWallpaperRemovesIndexThatDidNotExist() throws {
    let fixture = EngineFixture(indexContents: nil)
    _ = try fixture.engine.apply([.wallpaper])
    try fixture.files.write(Data("teal".utf8), to: indexURL)

    _ = try fixture.engine.restore([.wallpaper])

    #expect(fixture.files.snapshot[indexURL] == nil)
}

@Test func restoringAppearanceSwitchesToOriginalDarkMode() throws {
    let fixture = EngineFixture()
    _ = try fixture.engine.apply()
    fixture.log.events.removeAll()

    _ = try fixture.engine.restore()

    #expect(fixture.log.events.first == "switchAppearance(true)")
}
