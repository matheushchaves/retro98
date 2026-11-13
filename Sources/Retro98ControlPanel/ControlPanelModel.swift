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

/// Whether a piece can be switched, and how it is now.
enum Availability: Equatable {
    case on, off, notInstalled
}

struct ComponentsState: Equatable {
    let taskbar: Availability
    let fileViewer: Availability
    let hiddenMenuBar: Bool
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

    // MARK: Sounds

    func soundsOn() -> Bool {
        services.choices.load().soundsOn
    }

    func setSounds(on: Bool) -> [Problem] {
        save(services.choices.load().with(soundsOn: on))
    }

    /// The sound file is written before macOS is pointed at it, and removed once macOS no longer is.
    func setAlertSound(on: Bool) -> [Problem] {
        if on {
            do {
                try services.writeAlertSound()
            } catch {
                return [.fileFailed(String(describing: error))]
            }
            let problems = setTweaks(on: [.alertSound], off: [])
            if problems.contains(where: Self.isFailure) { services.removeAlertSound() }
            return problems
        }
        let problems = setTweaks(on: [], off: [.alertSound])
        if !problems.contains(where: Self.isFailure) { services.removeAlertSound() }
        return problems
    }

    // MARK: Components

    func components() throws -> ComponentsState {
        let managed = try managed()
        let shell = services.shell
        return ComponentsState(
            taskbar: shell.isInstalled ? (shell.isOn ? .on : .off) : .notInstalled,
            fileViewer: services.explorerInstalled ? (managed.contains(.explorerFileViewer) ? .on : .off) : .notInstalled,
            hiddenMenuBar: managed.contains(.hiddenMenuBar)
        )
    }

    /// On: hides the Dock under the taskbar, then starts it ("shell" in the pieces). Off: stops the taskbar,
    /// then gives the Dock back ("shelloff", so reinstalling keeps it off).
    func setTaskbar(on: Bool) -> [Problem] {
        let shell = services.shell
        guard shell.isInstalled else { return [.shellNotInstalled] }
        let pieces = services.pieces.load()
        if on {
            let problems = setTweaks(on: [.dockUnderTaskbar], off: [])
            guard !problems.contains(where: Self.isFailure) else { return problems }
            do {
                try shell.turnOn()
            } catch {
                // No taskbar: the Dock must not stay hidden.
                return setTweaks(on: [], off: [.dockUnderTaskbar]) + [.shellFailed(String(describing: error))]
            }
            return problems + save(pieces, as: pieces.replacing("shelloff", with: "shell"))
        }
        shell.turnOff()
        return setTweaks(on: [], off: [.dockUnderTaskbar]) + save(pieces, as: pieces.replacing("shell", with: "shelloff"))
    }

    func setFileViewer(on: Bool) -> [Problem] {
        let problems = on ? setTweaks(on: [.explorerFileViewer], off: []) : setTweaks(on: [], off: [.explorerFileViewer])
        guard !problems.contains(where: Self.isFailure) else { return problems }
        let pieces = services.pieces.load()
        return problems + save(pieces, as: on ? pieces.adding("fileviewer") : pieces.removing("fileviewer"))
    }

    /// Turns every piece off and restores everything in the backup; the apps stay installed. "base" leaves the
    /// pieces, so `./install.sh --yes` keeps macOS normal while an interactive "Yes" to the base tweaks brings
    /// them back. An unreadable backup stops it before anything changes.
    func backToNormal() -> [Problem] {
        let engine = services.makeEngine()
        do {
            _ = try engine.managed()
        } catch {
            return [unreadableBackup]
        }
        let pieces = services.pieces.load()
        var changed = pieces.removing("fileviewer").removing("base")
        // Also stops a taskbar that isn't the agent's (opened by hand, or left after crash recovery); harmless twice.
        if services.shell.isInstalled {
            services.shell.turnOff()
            if changed.contains("shell") { changed = changed.replacing("shell", with: "shelloff") }
        }
        var problems: [Problem] = []
        do {
            problems += Self.problems(in: try engine.restore())
        } catch is BackupError {
            problems.append(unreadableBackup)
        } catch {
            problems.append(.fileFailed(String(describing: error)))
        }
        services.removeAlertSound()
        return problems + save(pieces, as: changed)
    }

    // MARK: Shared

    nonisolated static func problems(in report: EngineReport) -> [Problem] {
        report.failed.map(Problem.failed) + report.warnings.map(Problem.warning)
    }

    nonisolated static func isFailure(_ problem: Problem) -> Bool {
        if case .warning = problem { return false }
        return true
    }

    /// Writes the pieces only when they changed: an install without a pieces file keeps not having one.
    func save(_ old: Pieces, as new: Pieces) -> [Problem] {
        guard new != old else { return [] }
        do {
            try services.pieces.save(new)
            return []
        } catch {
            return [.fileFailed(String(describing: error))]
        }
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
