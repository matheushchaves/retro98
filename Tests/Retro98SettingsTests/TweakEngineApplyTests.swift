import Foundation
import Testing
@testable import Retro98Settings

@Test func applyWritesEveryTargetAndRecordsOriginals() throws {
    let fixture = EngineFixture()
    let report = try fixture.engine.apply()

    #expect(report.succeeded == phase1Catalog.map(\.id))
    #expect(report.failed.isEmpty)
    #expect(try fixture.engine.status().allSatisfy { $0.state == .applied })
    let preferences = try fixture.backupFile.load().preferences
    #expect(preferences.first { $0.key == styleKey }?.original == .string("Dark"))
    #expect(preferences.first { $0.key == reduceTransparencyKey }?.original == nil)
    #expect(preferences.contains { $0.key == reduceTransparencyKey })
}

@Test func applyingTwiceKeepsFirstOriginals() throws {
    let fixture = EngineFixture()
    _ = try fixture.engine.apply()
    _ = try fixture.engine.apply()

    let backup = try fixture.backupFile.load()
    #expect(backup.preferences.first { $0.key == styleKey }?.original == .string("Dark"))
    #expect(backup.files.first?.original == originalIndex)
}

@Test func backupIsOnDiskBeforeFirstWrite() throws {
    let fixture = EngineFixture()
    var unprotectedWrites: [String] = []
    fixture.observer.beforeWrite = { key in
        let recorded = (try? fixture.backupFile.load().preferences.contains { $0.key == key }) ?? false
        if !recorded { unprotectedWrites.append(key.name) }
    }
    fixture.wallpaper.beforeSet = {
        let recorded = (try? fixture.backupFile.load().files.contains { $0.path == indexURL.path }) ?? false
        if !recorded { unprotectedWrites.append("wallpaper") }
    }

    _ = try fixture.engine.apply()

    #expect(unprotectedWrites.isEmpty)
}

@Test func deniedWriteRollsBackOnlyThatTweak() throws {
    let fixture = EngineFixture(deniedKeys: [increaseContrastKey])
    let report = try fixture.engine.apply([.contrast, .scrollBars])

    #expect(report.succeeded == [.scrollBars])
    #expect(report.failed == [TweakFailure(id: .contrast, reason: .writeDenied([increaseContrastKey]))])
    #expect(fixture.store.value(for: reduceTransparencyKey) == nil)
    #expect(fixture.store.value(for: scrollBarsKey) == .string("Always"))
    #expect(try fixture.backupFile.load().tweakIDs == [.scrollBars])
}

@Test func appearanceSwitchHappensBeforeWritesAndWarnsWhenItFails() throws {
    let fixture = EngineFixture()
    fixture.refresher.switchAppearanceResult = false
    let report = try fixture.engine.apply([.lightAppearance])

    #expect(fixture.log.events.first == "switchAppearance(false)")
    #expect(report.warnings == [.appearanceNeedsLogout])
}

@Test func appearanceIsNotSwitchedWhenNotSelected() throws {
    let fixture = EngineFixture()
    _ = try fixture.engine.apply([.scrollBars])
    #expect(!fixture.refresher.calls.contains { $0.hasPrefix("switchAppearance") })
}

@Test func effectsComeOnlyFromSucceededTweaks() throws {
    let fixture = EngineFixture(deniedKeys: [statusBarKey])
    _ = try fixture.engine.apply([.finderExplorer, .colors])
    #expect(fixture.refresher.calls == ["perform(notifyColorChange)"])
}

@Test func wallpaperBacksUpIndexAndSetsTeal() throws {
    let fixture = EngineFixture()
    let report = try fixture.engine.apply([.wallpaper])

    #expect(report.succeeded == [.wallpaper])
    #expect(fixture.wallpaper.hexes == ["#008080"])
    #expect(try fixture.backupFile.load().files
            == [FileBackupEntry(tweak: .wallpaper, path: indexURL.path, original: originalIndex)])
}

@Test func wallpaperFailureLeavesNoFileEntry() throws {
    let fixture = EngineFixture()
    fixture.wallpaper.error = FakeError()
    let report = try fixture.engine.apply([.wallpaper])

    #expect(report.failed.map(\.id) == [.wallpaper])
    #expect(try fixture.backupFile.load().files.isEmpty)
    #expect(fixture.files.snapshot[fixtureBackupURL] == nil)
}

@Test func statusReportsPartial() throws {
    let fixture = EngineFixture(preferences: [accentKey: .int(-1)])
    let states = Dictionary(uniqueKeysWithValues: try fixture.engine.status().map { ($0.id, $0.state) })

    #expect(states[.colors] == .partial)
    #expect(states[.scrollBars] == .notApplied)
    #expect(states[.wallpaper] == .notApplied)
}

// MARK: - Final review fixes

@Test func appearanceSwitchDoesNotCorruptRecordedOriginal() throws {
    let fixture = EngineFixture()
    fixture.refresher.onSwitch = { dark in
        try? fixture.store.write(dark ? .string("Dark") : nil, for: styleKey)
    }

    _ = try fixture.engine.apply()
    #expect(try fixture.backupFile.load().preferences.first { $0.key == styleKey }?.original == .string("Dark"))

    _ = try fixture.engine.restore()
    #expect(fixture.store.value(for: styleKey) == .string("Dark"))
}

@Test func applyWithCorruptedBackupChangesNothing() throws {
    let fixture = EngineFixture()
    try fixture.files.write(Data("garbage".utf8), to: fixtureBackupURL)

    #expect(throws: BackupError.self) { try fixture.engine.apply() }
    #expect(fixture.log.events.isEmpty)
    #expect(fixture.store.snapshot == machineLikePreferences)
}

@Test func failedRollbackKeepsOriginalInBackup() throws {
    let fixture = EngineFixture()
    fixture.observer.beforeWrite = { key in
        if key == increaseContrastKey {
            fixture.store.deniedKeys = [reduceTransparencyKey, increaseContrastKey]
        }
    }

    let report = try fixture.engine.apply([.contrast])

    #expect(report.failed.map(\.id) == [.contrast])
    #expect(fixture.store.value(for: reduceTransparencyKey) == .bool(true))
    let entry = try fixture.backupFile.load().preferences.first { $0.key == reduceTransparencyKey }
    #expect(entry != nil)
    #expect(entry?.original == nil)
}

@Test func partialWallpaperFailureKeepsIndexBackup() throws {
    let fixture = EngineFixture()
    fixture.wallpaper.beforeSet = { try? fixture.files.write(Data("teal".utf8), to: indexURL) }
    fixture.wallpaper.error = FakeError()

    let report = try fixture.engine.apply([.wallpaper])

    #expect(report.failed.map(\.id) == [.wallpaper])
    #expect(try fixture.backupFile.load().files
            == [FileBackupEntry(tweak: .wallpaper, path: indexURL.path, original: originalIndex)])
}

@Test func applySkipsWritesAlreadyAtTarget() throws {
    let fixture = EngineFixture(
        preferences: [reduceTransparencyKey: .bool(true), increaseContrastKey: .bool(true)],
        deniedKeys: [reduceTransparencyKey, increaseContrastKey]
    )

    let report = try fixture.engine.apply([.contrast])

    #expect(report.succeeded == [.contrast])
    #expect(report.failed.isEmpty)
}

private let pictureCatalog = TweakCatalog.phase1(
    osMajorVersion: 27, homeDirectory: URL(filePath: "/Users/test"),
    wallpaper: .picture(path: "/s/wallpaper-picture-1.png", name: "praia.png")
)

@Test func appliesPictureWallpaper() throws {
    let fixture = EngineFixture(catalog: pictureCatalog)
    let report = try fixture.engine.apply([.wallpaper])

    #expect(report.succeeded == [.wallpaper])
    #expect(fixture.wallpaper.pictures == [URL(filePath: "/s/wallpaper-picture-1.png")])
    #expect(fixture.wallpaper.hexes.isEmpty)
    #expect(try fixture.backupFile.load().files == [FileBackupEntry(tweak: .wallpaper, path: indexURL.path, original: originalIndex)])
}

@Test func missingPictureFailsAndKeepsBackup() throws {
    let fixture = EngineFixture(catalog: pictureCatalog)
    fixture.wallpaper.error = FakeError()
    let report = try fixture.engine.apply([.wallpaper])

    #expect(report.succeeded.isEmpty)
    #expect(report.failed.map(\.id) == [.wallpaper])
    if case .wallpaperFailed = report.failed.first?.reason {} else { Issue.record("expected wallpaperFailed") }
    #expect(try fixture.files.read(indexURL) == originalIndex)
    #expect(try fixture.backupFile.load().files.isEmpty)
}

@Test func managedListsTweaksInBackup() throws {
    let fixture = EngineFixture()
    _ = try fixture.engine.apply([.pointer, .wallpaper])
    #expect(try fixture.engine.managed() == [.pointer, .wallpaper])
    _ = try fixture.engine.restore([.pointer])
    #expect(try fixture.engine.managed() == [.wallpaper])
}
