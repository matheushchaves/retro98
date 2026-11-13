import AppKit
@testable import Retro98ControlPanel
import Retro98Settings
import Retro98UI

let pt = ["pt-BR"]
let originalIndex = Data("original".utf8)

final class FakeWallpaper: WallpaperSetter {
    var hexes: [String] = []
    var pictures: [URL] = []
    var restoredIndexes: [Data?] = []
    private let files: FileStore

    init(files: FileStore) { self.files = files }

    func setSolidColor(hex: String) throws { hexes.append(hex) }
    func setPicture(_ url: URL) throws { pictures.append(url) }

    func restoreIndex(_ original: Data?, at index: URL) throws -> WallpaperRestore {
        restoredIndexes.append(original)
        try files.write(original, to: index)
        return .original
    }
}

final class FakeRefresher: SystemRefresher {
    var effects: [Set<RefreshEffect>] = []
    func switchAppearance(toDark dark: Bool) -> Bool { true }
    func perform(_ effects: Set<RefreshEffect>) { self.effects.append(effects) }
}

final class FakeShell: ShellSwitch {
    var isInstalled = true
    var isOn = false
    var turnOnCalls = 0
    var turnOffCalls = 0
    var turnOnError: Error?
    /// Runs inside turnOn, before it succeeds (to look at what was already applied).
    var onTurnOn: (() -> Void)?

    func turnOn() throws {
        turnOnCalls += 1
        onTurnOn?()
        if let turnOnError { throw turnOnError }
        isOn = true
    }

    func turnOff() {
        turnOffCalls += 1
        isOn = false
    }
}

struct TestError: Error, Equatable {}

/// Everything in memory: a real TweakEngine over in-memory preferences and files, fake wallpaper and Shell.
@MainActor final class TestServices: ControlPanelServices {
    let languages: [String]
    let paths = Retro98Paths.standard(home: URL(filePath: "/Users/ana"), environment: [
        "RETRO98_SUPPORT_DIR": "/s", "RETRO98_APPS_DIR": "/apps", "RETRO98_LAUNCH_AGENTS_DIR": "/agents",
        "RETRO98_SOUNDS_DIR": "/sounds",
    ])
    let store: InMemoryPreferenceStore
    let files: InMemoryFileStore
    let wallpaper: FakeWallpaper
    let refresher = FakeRefresher()
    let fakeShell = FakeShell()
    var shell: ShellSwitch { fakeShell }
    var explorerInstalled = true
    private(set) var opened: [URL] = []
    private(set) var previewed: [RetroSoundKind] = []
    /// Ordered record of sound-file and Shell steps.
    private(set) var events: [String] = []
    var alertSoundError: Error?

    init(preferences: [PreferenceKey: PreferenceValue] = [:], deniedKeys: Set<PreferenceKey> = [], languages: [String] = pt) {
        self.languages = languages
        store = InMemoryPreferenceStore(preferences, deniedKeys: deniedKeys)
        files = InMemoryFileStore()
        wallpaper = FakeWallpaper(files: files)
        try? files.write(originalIndex, to: paths.wallpaperIndex)
    }

    var choices: ChoicesFile { ChoicesFile(url: paths.choicesFile, files: files) }
    var pieces: PiecesFile { PiecesFile(url: paths.piecesFile, files: files) }

    func catalog() -> [Tweak] {
        TweakCatalog.all(osMajorVersion: 27, homeDirectory: URL(filePath: "/Users/ana"), wallpaper: choices.load().wallpaper,
                         alertSoundPath: paths.alertSoundFile.path)
    }

    func makeEngine() -> TweakEngine {
        TweakEngine(catalog: catalog(), store: store, files: files, backupFile: BackupFile(url: paths.backupFile, files: files),
                    wallpaperIndex: paths.wallpaperIndex, wallpaper: wallpaper, refresher: refresher)
    }

    func open(_ url: URL) { opened.append(url) }

    /// Checks the picture like the real one, without copying anything.
    func adoptPicture(_ url: URL) throws -> WallpaperChoice {
        guard NSImage(contentsOf: url) != nil else { throw PictureWallpaperError.notAnImage }
        return .picture(path: "/s/wallpaper-picture-1.png", name: url.lastPathComponent)
    }

    func writeAlertSound() throws {
        events.append("writeAlertSound")
        if let alertSoundError { throw alertSoundError }
        try files.write(RetroSound.aiff(.alert), to: paths.alertSoundFile)
    }

    func removeAlertSound() {
        events.append("removeAlertSound")
        try? files.write(nil, to: paths.alertSoundFile)
    }

    func preview(_ sound: RetroSoundKind) { previewed.append(sound) }

    var alertSoundExists: Bool { ((try? files.read(paths.alertSoundFile)) ?? nil) != nil }
}

@MainActor final class ScriptedPrompter: ControlPanelPrompter {
    struct Shown: Equatable {
        let title: String
        let message: String
        let icon: MessageBoxIcon
        let buttons: [String]
    }

    var answers: [Int] = []
    private(set) var shown: [Shown] = []

    func show(title: String, message: String, icon: MessageBoxIcon, buttons: [String]) -> Int {
        shown.append(Shown(title: title, message: message, icon: icon, buttons: buttons))
        return answers.isEmpty ? buttons.count - 1 : answers.removeFirst()
    }
}
