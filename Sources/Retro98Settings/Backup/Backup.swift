import Foundation

public struct PreferenceBackupEntry: Codable, Equatable, Sendable {
    public let tweak: TweakID
    public let key: PreferenceKey
    /// nil means the key did not exist before Retro98 touched it.
    public let original: PreferenceValue?

    public init(tweak: TweakID, key: PreferenceKey, original: PreferenceValue?) {
        self.tweak = tweak
        self.key = key
        self.original = original
    }
}

public struct FileBackupEntry: Codable, Equatable, Sendable {
    public let tweak: TweakID
    public let path: String
    /// nil means the file did not exist before Retro98 touched it.
    public let original: Data?

    public init(tweak: TweakID, path: String, original: Data?) {
        self.tweak = tweak
        self.path = path
        self.original = original
    }
}

public enum BackupError: Error, Equatable {
    case corrupted(String)
    case unsupportedVersion(Int)
}

/// The original state of everything Retro98 changed. Recording never replaces an
/// existing original, so re-applying keeps the values from before the first install.
public struct Backup: Codable, Equatable, Sendable {
    public static let currentVersion = 1
    public static let empty = Backup(version: currentVersion, preferences: [], files: [])

    public let version: Int
    public let preferences: [PreferenceBackupEntry]
    public let files: [FileBackupEntry]

    public func recording(_ entry: PreferenceBackupEntry) -> Backup {
        guard !preferences.contains(where: { $0.key == entry.key }) else { return self }
        return Backup(version: version, preferences: preferences + [entry], files: files)
    }

    public func recording(_ entry: FileBackupEntry) -> Backup {
        guard !files.contains(where: { $0.path == entry.path }) else { return self }
        return Backup(version: version, preferences: preferences, files: files + [entry])
    }

    public func removing(tweaks: Set<TweakID>) -> Backup {
        Backup(
            version: version,
            preferences: preferences.filter { !tweaks.contains($0.tweak) },
            files: files.filter { !tweaks.contains($0.tweak) }
        )
    }

    public var tweakIDs: Set<TweakID> {
        Set(preferences.map(\.tweak)).union(files.map(\.tweak))
    }

    public var isEmpty: Bool { preferences.isEmpty && files.isEmpty }
}
