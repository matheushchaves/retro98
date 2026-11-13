import Foundation

/// The tweak engine wired to the real Mac: CFPreferences, local files, NSWorkspace, killall.
/// Shared by the CLI and the Shell so both read and write the same backup.
public struct SystemEngine {
    public let engine: TweakEngine
    public let paths: Retro98Paths
    public let catalog: [Tweak]

    public static func make(
        home: URL = FileManager.default.homeDirectoryForCurrentUser,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        osMajorVersion: Int = ProcessInfo.processInfo.operatingSystemVersion.majorVersion
    ) -> SystemEngine {
        let paths = Retro98Paths.standard(home: home, environment: environment)
        let files = LocalFileStore()
        let choices = ChoicesFile(url: paths.choicesFile, files: files).load()
        let catalog = TweakCatalog.all(osMajorVersion: osMajorVersion, homeDirectory: home, wallpaper: choices.wallpaper)
        let engine = TweakEngine(
            catalog: catalog, store: CFPreferenceStore(), files: files,
            backupFile: BackupFile(url: paths.backupFile, files: files),
            wallpaperIndex: paths.wallpaperIndex,
            wallpaper: MacWallpaperSetter(paths: paths, files: files),
            refresher: MacSystemRefresher()
        )
        return SystemEngine(engine: engine, paths: paths, catalog: catalog)
    }
}
