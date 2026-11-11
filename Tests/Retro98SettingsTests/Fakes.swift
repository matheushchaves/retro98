import Foundation
@testable import Retro98Settings

/// Shared, ordered record of side effects across fakes.
final class EventLog {
    var events: [String] = []
}

struct FakeError: Error, Equatable {}

final class FakeWallpaperSetter: WallpaperSetter {
    var hexes: [String] = []
    var error: Error?
    var beforeSet: (() -> Void)?

    func setSolidColor(hex: String) throws {
        beforeSet?()
        if let error { throw error }
        hexes.append(hex)
    }
}

final class RecordingRefresher: SystemRefresher {
    private let log: EventLog
    var switchAppearanceResult = true

    init(log: EventLog) {
        self.log = log
    }

    var calls: [String] { log.events.filter { !$0.hasPrefix("write(") } }

    func switchAppearance(toDark dark: Bool) -> Bool {
        log.events.append("switchAppearance(\(dark))")
        return switchAppearanceResult
    }

    func perform(_ effects: Set<RefreshEffect>) {
        let names = effects.map { String(describing: $0) }.sorted().joined(separator: ",")
        log.events.append("perform(\(names))")
    }
}

final class ObservingPreferenceStore: PreferenceStore {
    private let inner: PreferenceStore
    private let onWrite: (PreferenceKey) -> Void
    var beforeWrite: ((PreferenceKey) -> Void)?

    init(wrapping inner: PreferenceStore, onWrite: @escaping (PreferenceKey) -> Void) {
        self.inner = inner
        self.onWrite = onWrite
    }

    func value(for key: PreferenceKey) -> PreferenceValue? { inner.value(for: key) }

    func write(_ value: PreferenceValue?, for key: PreferenceKey) throws(PreferenceError) {
        beforeWrite?(key)
        onWrite(key)
        try inner.write(value, for: key)
    }
}

// MARK: - Engine fixture

let universalAccessDomain = PreferenceDomain.app("com.apple.universalaccess")
let finderDomain = PreferenceDomain.app("com.apple.finder")
let styleKey = PreferenceKey(domain: .global, name: "AppleInterfaceStyle")
let autoSwitchKey = PreferenceKey(domain: .global, name: "AppleInterfaceStyleSwitchesAutomatically")
let reduceTransparencyKey = PreferenceKey(domain: universalAccessDomain, name: "reduceTransparency")
let increaseContrastKey = PreferenceKey(domain: universalAccessDomain, name: "increaseContrast")
let cursorFillKey = PreferenceKey(domain: universalAccessDomain, name: "cursorFill")
let cursorOutlineKey = PreferenceKey(domain: universalAccessDomain, name: "cursorOutline")
let accentKey = PreferenceKey(domain: .global, name: "AppleAccentColor")
let statusBarKey = PreferenceKey(domain: finderDomain, name: "ShowStatusBar")
let scrollBarsKey = PreferenceKey(domain: .global, name: "AppleShowScrollBars")

let indexURL = URL(filePath: "/home/Library/Application Support/com.apple.wallpaper/Store/Index.plist")
let fixtureBackupURL = URL(filePath: "/home/Library/Application Support/Retro98/backup.plist")
let originalIndex = Data("aerials".utf8)

let phase1Catalog = TweakCatalog.phase1(osMajorVersion: 27, homeDirectory: URL(filePath: "/Users/test"))

let initialCursorOutline = PreferenceValue.dictionary(["alpha": .int(1), "red": .int(0), "green": .int(0), "blue": .int(0)])

/// Mirrors the values read from the author's Mac on 2026-11-10.
let machineLikePreferences: [PreferenceKey: PreferenceValue] = [
    styleKey: .string("Dark"),
    autoSwitchKey: .bool(true),
    PreferenceKey(domain: universalAccessDomain, name: "cursorIsCustomized"): .bool(true),
    cursorFillKey: .dictionary([
        "alpha": .int(1), "red": .double(0.994845449924469),
        "green": .double(0.994845449924469), "blue": .double(0.994845449924469),
    ]),
    cursorOutlineKey: initialCursorOutline,
    PreferenceKey(domain: finderDomain, name: "FXPreferredViewStyle"): .string("Nlsv"),
    PreferenceKey(domain: finderDomain, name: "NewWindowTarget"): .string("PfAF"),
]

final class EngineFixture {
    let log = EventLog()
    let store: InMemoryPreferenceStore
    let observer: ObservingPreferenceStore
    let files: InMemoryFileStore
    let backupFile: BackupFile
    let wallpaper = FakeWallpaperSetter()
    let refresher: RecordingRefresher
    let engine: TweakEngine

    init(
        preferences: [PreferenceKey: PreferenceValue] = machineLikePreferences,
        indexContents: Data? = originalIndex,
        deniedKeys: Set<PreferenceKey> = []
    ) {
        store = InMemoryPreferenceStore(preferences, deniedKeys: deniedKeys)
        let log = self.log
        observer = ObservingPreferenceStore(wrapping: store) { key in log.events.append("write(\(key.name))") }
        files = InMemoryFileStore(indexContents.map { [indexURL: $0] } ?? [:])
        backupFile = BackupFile(url: fixtureBackupURL, files: files)
        refresher = RecordingRefresher(log: log)
        engine = TweakEngine(
            catalog: phase1Catalog, store: observer, files: files, backupFile: backupFile,
            wallpaperIndex: indexURL, wallpaper: wallpaper, refresher: refresher
        )
    }
}
