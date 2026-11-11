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
        var backup = try backupFile.load()
        var succeeded: [TweakID] = []
        var failed: [TweakFailure] = []
        var warnings: [EngineWarning] = []
        for tweak in selected {
            let outcome = try apply(tweak, backup: backup)
            backup = outcome.backup
            warnings += outcome.warnings
            if let failure = outcome.failure { failed.append(failure) } else { succeeded.append(tweak.id) }
        }

        performEffects(of: selected.filter { succeeded.contains($0.id) })
        return EngineReport(succeeded: succeeded, failed: failed, warnings: warnings)
    }

    private typealias PreviousValues = [(key: PreferenceKey, value: PreferenceValue?)]

    private struct TweakOutcome {
        let backup: Backup
        let failure: TweakFailure?
        let warnings: [EngineWarning]
    }

    private func apply(_ tweak: Tweak, backup: Backup) throws -> TweakOutcome {
        let previous = tweak.changes.map { (key: $0.key, value: store.value(for: $0.key)) }
        let capturesIndex = tweak.special != nil
        let indexBefore = capturesIndex ? try files.read(wallpaperIndex) : nil
        let recorded = record(tweak, previous: previous, includeIndex: capturesIndex, indexBefore: indexBefore, into: backup)
        try backupFile.save(recorded)

        // The originals are on disk; only now may anything change, including the live appearance switch.
        let warnings = switchAppearanceIfNeeded(
            for: [tweak],
            toDark: { tweak in tweak.changes.first { $0.key == Self.appearanceKey }?.target == .string("Dark") }
        )
        guard let reason = performChanges(of: tweak, previous: previous) else {
            return TweakOutcome(backup: recorded, failure: nil, warnings: warnings)
        }

        // Keep the originals of whatever is still changed after the rollback; drop the rest.
        let stillChanged = previous.filter { store.value(for: $0.key) != $0.value }
        let indexChanged = capturesIndex && (try? files.read(wallpaperIndex)) != indexBefore
        let kept = record(tweak, previous: stillChanged, includeIndex: indexChanged, indexBefore: indexBefore, into: backup)
        try backupFile.save(kept)
        return TweakOutcome(backup: kept, failure: TweakFailure(id: tweak.id, reason: reason), warnings: warnings)
    }

    private func record(
        _ tweak: Tweak, previous: PreviousValues, includeIndex: Bool, indexBefore: Data?, into backup: Backup
    ) -> Backup {
        let withPreferences = previous.reduce(backup) {
            $0.recording(PreferenceBackupEntry(tweak: tweak.id, key: $1.key, original: $1.value))
        }
        guard includeIndex else { return withPreferences }
        return withPreferences.recording(FileBackupEntry(tweak: tweak.id, path: wallpaperIndex.path, original: indexBefore))
    }

    /// Writes the targets that differ and runs the special action. On failure, puts back
    /// every key that no longer holds its previous value and returns why.
    private func performChanges(of tweak: Tweak, previous: PreviousValues) -> FailureReason? {
        let rollBack = {
            previous.reversed()
                .filter { store.value(for: $0.key) != $0.value }
                .forEach { try? store.write($0.value, for: $0.key) }
        }
        for change in tweak.changes where store.value(for: change.key) != change.target {
            do {
                try store.write(change.target, for: change.key)
            } catch {
                rollBack()
                return .writeDenied([change.key])
            }
        }
        if case .solidWallpaper(let hex) = tweak.special {
            do {
                try wallpaper.setSolidColor(hex: hex)
            } catch {
                rollBack()
                return .wallpaperFailed(String(describing: error))
            }
        }
        return nil
    }

    // MARK: Restore

    /// Puts back the originals of the selected tweaks (everything in the backup when nil).
    /// A corrupted or newer backup throws before anything is touched. Entries of tweaks
    /// that could not be restored stay in the backup so the restore can be retried.
    public func restore(_ ids: Set<TweakID>? = nil) throws -> EngineReport {
        let backup = try backupFile.load()
        let selected = catalog.filter { backup.tweakIDs.contains($0.id) && (ids?.contains($0.id) ?? true) }
        guard !selected.isEmpty else { return EngineReport(succeeded: [], failed: [], warnings: []) }

        let warnings = switchAppearanceIfNeeded(
            for: selected,
            toDark: { tweak in
                backup.preferences.first { $0.tweak == tweak.id && $0.key == Self.appearanceKey }?.original
                    == .string("Dark")
            }
        )
        let outcomes = selected.map { (tweak: $0, reason: restore($0, from: backup)) }
        let succeeded = outcomes.filter { $0.reason == nil }.map(\.tweak.id)
        let failed = outcomes.compactMap { outcome in
            outcome.reason.map { TweakFailure(id: outcome.tweak.id, reason: $0) }
        }

        try backupFile.save(backup.removing(tweaks: Set(succeeded)))
        let restoredFiles = backup.files.contains { succeeded.contains($0.tweak) }
        performEffects(
            of: selected.filter { succeeded.contains($0.id) },
            extra: restoredFiles ? [.restartWallpaperAgent] : []
        )
        return EngineReport(succeeded: succeeded, failed: failed, warnings: warnings)
    }

    private func restore(_ tweak: Tweak, from backup: Backup) -> FailureReason? {
        let denied = backup.preferences.filter { $0.tweak == tweak.id }.compactMap { entry -> PreferenceKey? in
            // Already back at the original (e.g. fixed by hand): nothing to write, so nothing to deny.
            guard store.value(for: entry.key) != entry.original else { return nil }
            do {
                try store.write(entry.original, for: entry.key)
                return nil
            } catch {
                return entry.key
            }
        }
        guard denied.isEmpty else { return .writeDenied(denied) }

        for entry in backup.files
        where entry.tweak == tweak.id && (try? files.read(URL(filePath: entry.path))) != entry.original {
            do {
                try files.write(entry.original, to: URL(filePath: entry.path))
            } catch {
                return .fileWriteFailed(String(describing: error))
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
