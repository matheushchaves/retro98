import Foundation
import Retro98Settings

/// Something that went wrong (or needs saying) after a change in the Control Panel.
enum Problem: Equatable {
    case failed(TweakFailure)
    case warning(EngineWarning)
    case backupUnreadable(path: String)
    case notAnImage(name: String)
    case shellNotInstalled
    case shellFailed(String)
    case fileFailed(String)
}

/// The Control Panel's logic: turns tweaks and pieces on and off through the tweak engine and remembers the
/// person's choices, so `./install.sh --yes` keeps them.
@MainActor
final class ControlPanelModel {
    let services: ControlPanelServices

    init(services: ControlPanelServices) {
        self.services = services
    }

    var languages: [String] { services.languages }
    private var unreadableBackup: Problem { .backupUnreadable(path: services.paths.backupFile.path) }

    /// The tweaks Retro98 manages right now ("on" in the panel).
    func managed() throws -> Set<TweakID> {
        try services.makeEngine().managed()
    }

    func title(of id: TweakID) -> String {
        services.catalog().first { $0.id == id }?.title.resolve(for: languages) ?? id.rawValue
    }

    // MARK: Tweaks

    /// Applies `on` and restores `off`. Base tweaks that changed are remembered as on or off.
    func setTweaks(on: Set<TweakID>, off: Set<TweakID>) -> [Problem] {
        let engine = services.makeEngine()
        let base = Set(services.catalog().filter { $0.group == .base }.map(\.id))
        var choices = services.choices.load()
        var problems: [Problem] = []
        do {
            if !on.isEmpty {
                let report = try engine.apply(on)
                problems += Self.problems(in: report)
                for id in report.succeeded where base.contains(id) { choices = choices.turning(id, on: true) }
            }
            if !off.isEmpty {
                let report = try engine.restore(off)
                problems += Self.problems(in: report)
                // A tweak with nothing in the backup is already off.
                let failed = Set(report.failed.map(\.id))
                for id in off where base.contains(id) && !failed.contains(id) { choices = choices.turning(id, on: false) }
            }
        } catch is BackupError {
            return [unreadableBackup]
        } catch {
            return problems + [.fileFailed(String(describing: error))]
        }
        return problems + save(choices)
    }

    // MARK: Wallpaper

    /// The wallpaper Retro98 shows, or nil when the macOS wallpaper is in use.
    func wallpaper() throws -> WallpaperChoice? {
        try managed().contains(.wallpaper) ? services.choices.load().wallpaper : nil
    }

    /// A choice is saved first (the engine reads it), then applied; on failure the previous choice comes back.
    /// nil gives back the macOS wallpaper.
    func setWallpaper(_ choice: WallpaperChoice?) -> [Problem] {
        let previous = services.choices.load()
        guard let choice else { return setTweaks(on: [], off: [.wallpaper]) }
        let saveProblems = save(previous.with(wallpaper: choice))
        guard saveProblems.isEmpty else { return saveProblems }
        let problems = setTweaks(on: [.wallpaper], off: [])
        if problems.contains(where: Self.isFailure) {
            _ = save(services.choices.load().with(wallpaper: previous.wallpaper))
        }
        return problems
    }

    // MARK: Shared

    nonisolated static func problems(in report: EngineReport) -> [Problem] {
        report.failed.map(Problem.failed) + report.warnings.map(Problem.warning)
    }

    nonisolated static func isFailure(_ problem: Problem) -> Bool {
        if case .warning = problem { return false }
        return true
    }

    func save(_ choices: Choices) -> [Problem] {
        do {
            try services.choices.save(choices)
            return []
        } catch {
            return [.fileFailed(String(describing: error))]
        }
    }
}
