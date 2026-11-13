import AppKit
import Retro98Settings
import Retro98UI

/// What the Control Panel asks of the Mac. Tests use an in-memory version.
@MainActor
protocol ControlPanelServices: AnyObject {
    var languages: [String] { get }
    var paths: Retro98Paths { get }
    /// A fresh engine whose catalog follows the saved wallpaper choice.
    func makeEngine() -> TweakEngine
    func catalog() -> [Tweak]
    var choices: ChoicesFile { get }
    var pieces: PiecesFile { get }
    var shell: ShellSwitch { get }
    var explorerInstalled: Bool { get }
    func open(_ url: URL)
    func adoptPicture(_ url: URL) throws -> WallpaperChoice
    /// Writes Retro98's alert sound where macOS looks for the person's alert sounds.
    func writeAlertSound() throws
    func removeAlertSound()
    func preview(_ sound: RetroSoundKind)
}

@MainActor
final class LiveControlPanelServices: ControlPanelServices {
    let languages = Locale.preferredLanguages
    let paths = SystemEngine.make().paths
    private let files = LocalFileStore()
    lazy var shell: ShellSwitch = ShellAgent(paths: paths, files: files, runner: ProcessCommandRunner())

    func makeEngine() -> TweakEngine { SystemEngine.make().engine }
    func catalog() -> [Tweak] { SystemEngine.make().catalog }
    var choices: ChoicesFile { ChoicesFile(url: paths.choicesFile, files: files) }
    var pieces: PiecesFile { PiecesFile(url: paths.piecesFile, files: files) }
    var explorerInstalled: Bool { FileManager.default.fileExists(atPath: paths.explorerApp.path) }

    func open(_ url: URL) { NSWorkspace.shared.open(url) }
    func adoptPicture(_ url: URL) throws -> WallpaperChoice { try PictureWallpaper.adopt(url, paths: paths) }
    func writeAlertSound() throws { try files.write(RetroSound.aiff(.alert), to: paths.alertSoundFile) }
    func removeAlertSound() { try? files.write(nil, to: paths.alertSoundFile) }
    func preview(_ sound: RetroSoundKind) { RetroSound.preview(sound) }
}
