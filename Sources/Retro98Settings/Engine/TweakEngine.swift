import Foundation

public enum FailureReason: Equatable, Sendable {
    case writeDenied([PreferenceKey])
    case wallpaperFailed(String)
    case fileWriteFailed(String)
}

public struct TweakFailure: Equatable, Sendable {
    public let id: TweakID
    public let reason: FailureReason
}

public enum EngineWarning: Equatable, Sendable {
    case appearanceNeedsLogout
}

public struct EngineReport: Equatable, Sendable {
    public let succeeded: [TweakID]
    public let failed: [TweakFailure]
    public let warnings: [EngineWarning]
}

public enum TweakState: Equatable, Sendable {
    case applied, partial, notApplied
}

public struct TweakStatus: Equatable, Sendable {
    public let id: TweakID
    public let state: TweakState
}

/// Applies, restores and inspects tweaks. Every original value reaches the backup file
/// on disk before the setting it belongs to is changed.
public struct TweakEngine {
    static let appearanceKey = PreferenceKey(domain: .global, name: "AppleInterfaceStyle")

    private let catalog: [Tweak]
    private let store: PreferenceStore
    private let files: FileStore
    private let backupFile: BackupFile
    private let wallpaperIndex: URL
    private let wallpaper: WallpaperSetter
    private let refresher: SystemRefresher

    public init(
        catalog: [Tweak], store: PreferenceStore, files: FileStore, backupFile: BackupFile,
        wallpaperIndex: URL, wallpaper: WallpaperSetter, refresher: SystemRefresher
    ) {
        self.catalog = catalog
        self.store = store
        self.files = files
        self.backupFile = backupFile
        self.wallpaperIndex = wallpaperIndex
        self.wallpaper = wallpaper
        self.refresher = refresher
    }

    // MARK: Apply

    /// Applies the selected tweaks (all when nil). Throws only when the backup cannot be read or saved.
    public func apply(_ ids: Set<TweakID>? = nil) throws -> EngineReport {
        let selected = catalog.filter { ids?.contains($0.id) ?? true }
        let warnings = switchAppearanceIfNeeded(
            for: selected,
            toDark: { tweak in tweak.changes.first { $0.key == Self.appearanceKey }?.target == .string("Dark") }
        )

        var backup = try backupFile.load()
        var succeeded: [TweakID] = []
        var failed: [TweakFailure] = []
        for tweak in selected {
            let (updatedBackup, failure) = try apply(tweak, backup: backup)
            backup = updatedBackup
            if let failure { failed.append(failure) } else { succeeded.append(tweak.id) }
        }

        performEffects(of: selected.filter { succeeded.contains($0.id) })
        return EngineReport(succeeded: succeeded, failed: failed, warnings: warnings)
    }

    private func apply(_ tweak: Tweak, backup: Backup) throws -> (Backup, TweakFailure?) {
        let previous = tweak.changes.map { (key: $0.key, value: store.value(for: $0.key)) }
        let withPreferences = previous.reduce(backup) {
            $0.recording(PreferenceBackupEntry(tweak: tweak.id, key: $1.key, original: $1.value))
        }
        let recorded = tweak.special == nil
            ? withPreferences
            : withPreferences.recording(
                FileBackupEntry(tweak: tweak.id, path: wallpaperIndex.path, original: try files.read(wallpaperIndex))
            )
        try backupFile.save(recorded)

        guard let reason = performChanges(of: tweak, previous: previous) else { return (recorded, nil) }
        // Nothing of this tweak stayed changed, so its new backup entries are dropped again.
        try backupFile.save(backup)
        return (backup, TweakFailure(id: tweak.id, reason: reason))
    }

    /// Writes the tweak's targets and runs its special action. On failure, puts back
    /// what this run already changed and returns why.
    private func performChanges(of tweak: Tweak, previous: [(key: PreferenceKey, value: PreferenceValue?)]) -> FailureReason? {
        let rollBack = { (count: Int) in
            previous.prefix(count).reversed().forEach { try? store.write($0.value, for: $0.key) }
        }
        for (index, change) in tweak.changes.enumerated() {
            do {
                try store.write(change.target, for: change.key)
            } catch {
                rollBack(index)
                return .writeDenied([change.key])
            }
        }
        if case .solidWallpaper(let hex) = tweak.special {
            do {
                try wallpaper.setSolidColor(hex: hex)
            } catch {
                rollBack(tweak.changes.count)
                return .wallpaperFailed(String(describing: error))
            }
        }
        return nil
    }

    // MARK: Status

    public func status() throws -> [TweakStatus] {
        let backup = try backupFile.load()
        return catalog.map { tweak in
            guard !tweak.changes.isEmpty else {
                let applied = backup.files.contains { $0.tweak == tweak.id }
                return TweakStatus(id: tweak.id, state: applied ? .applied : .notApplied)
            }
            let matching = tweak.changes.filter { store.value(for: $0.key) == $0.target }.count
            let state: TweakState = matching == tweak.changes.count ? .applied : (matching == 0 ? .notApplied : .partial)
            return TweakStatus(id: tweak.id, state: state)
        }
    }

    // MARK: Shared

    private func switchAppearanceIfNeeded(for tweaks: [Tweak], toDark: (Tweak) -> Bool) -> [EngineWarning] {
        guard let appearance = tweaks.first(where: { $0.effects.contains(.syncAppearance) }) else { return [] }
        return refresher.switchAppearance(toDark: toDark(appearance)) ? [] : [.appearanceNeedsLogout]
    }

    private func performEffects(of tweaks: [Tweak], extra: Set<RefreshEffect> = []) {
        let effects = tweaks.reduce(extra) { $0.union($1.effects) }
        guard !effects.isEmpty else { return }
        refresher.perform(effects)
    }
}
