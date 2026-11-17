import Foundation

/// What the Retro98 wallpaper shows: a solid color or a picture copied into the support folder.
public enum WallpaperChoice: Equatable, Sendable {
    case color(hex: String)
    case picture(path: String, name: String)

    public static let standard = WallpaperChoice.color(hex: TweakCatalog.teal)
}

/// What the person chose in the Control Panel. `./install.sh --yes` keeps these: turned-off base tweaks
/// stay off and the chosen wallpaper comes back.
public struct Choices: Equatable, Sendable {
    public let wallpaper: WallpaperChoice
    /// Base tweaks turned off in the Control Panel.
    public let turnedOff: Set<TweakID>
    public let soundsOn: Bool
    public let screensaver: ScreensaverKind
    /// Idle timeout in minutes before the screensaver activates.
    public let screensaverTimeout: Int
    /// Whether the screensaver plays its own sounds (the island's sea and effects). Separate from `soundsOn`,
    /// and off unless the person turns it on: a noisy screensaver shouldn't surprise anyone.
    public let screensaverSound: Bool

    public static let standard = Choices(
        wallpaper: .standard, turnedOff: [], soundsOn: true,
        screensaver: .standard, screensaverTimeout: 5, screensaverSound: false
    )

    public init(wallpaper: WallpaperChoice, turnedOff: Set<TweakID>, soundsOn: Bool,
                screensaver: ScreensaverKind = .standard, screensaverTimeout: Int = 5,
                screensaverSound: Bool = false) {
        self.wallpaper = wallpaper
        self.turnedOff = turnedOff
        self.soundsOn = soundsOn
        self.screensaver = screensaver
        self.screensaverTimeout = screensaverTimeout
        self.screensaverSound = screensaverSound
    }

    public func with(wallpaper: WallpaperChoice) -> Choices {
        Choices(wallpaper: wallpaper, turnedOff: turnedOff, soundsOn: soundsOn,
                screensaver: screensaver, screensaverTimeout: screensaverTimeout,
                screensaverSound: screensaverSound)
    }

    public func with(soundsOn: Bool) -> Choices {
        Choices(wallpaper: wallpaper, turnedOff: turnedOff, soundsOn: soundsOn,
                screensaver: screensaver, screensaverTimeout: screensaverTimeout,
                screensaverSound: screensaverSound)
    }

    public func with(screensaver: ScreensaverKind) -> Choices {
        Choices(wallpaper: wallpaper, turnedOff: turnedOff, soundsOn: soundsOn,
                screensaver: screensaver, screensaverTimeout: screensaverTimeout,
                screensaverSound: screensaverSound)
    }

    public func with(screensaverTimeout: Int) -> Choices {
        Choices(wallpaper: wallpaper, turnedOff: turnedOff, soundsOn: soundsOn,
                screensaver: screensaver, screensaverTimeout: screensaverTimeout,
                screensaverSound: screensaverSound)
    }

    public func with(screensaverSound: Bool) -> Choices {
        Choices(wallpaper: wallpaper, turnedOff: turnedOff, soundsOn: soundsOn,
                screensaver: screensaver, screensaverTimeout: screensaverTimeout,
                screensaverSound: screensaverSound)
    }

    public func turning(_ id: TweakID, on: Bool) -> Choices {
        Choices(wallpaper: wallpaper,
                turnedOff: on ? turnedOff.subtracting([id]) : turnedOff.union([id]),
                soundsOn: soundsOn, screensaver: screensaver, screensaverTimeout: screensaverTimeout,
                screensaverSound: screensaverSound)
    }
}

/// `choices.plist` in the support folder. A missing or unreadable file, or a missing key, means the
/// standard value, so a broken file never stops an install.
public struct ChoicesFile {
    private let url: URL
    private let files: FileStore

    public init(url: URL, files: FileStore) {
        self.url = url
        self.files = files
    }

    /// The person's own file, as the apps and the CLI see it.
    public static func live() -> ChoicesFile {
        let paths = Retro98Paths.standard(home: FileManager.default.homeDirectoryForCurrentUser,
                                          environment: ProcessInfo.processInfo.environment)
        return ChoicesFile(url: paths.choicesFile, files: LocalFileStore())
    }

    public func load() -> Choices {
        guard let data = try? files.read(url),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        else { return .standard }
        let names = plist["turnedOff"] as? [String] ?? []
        let screensaver = (plist["screensaver"] as? String)
            .flatMap(ScreensaverKind.init(saved:)) ?? .standard
        let screensaverTimeout = plist["screensaverTimeout"] as? Int ?? 5
        return Choices(
            wallpaper: Self.wallpaper(from: plist["wallpaper"] as? [String: Any]) ?? .standard,
            turnedOff: Set(names.compactMap(TweakID.init(rawValue:))),
            soundsOn: plist["soundsOn"] as? Bool ?? Choices.standard.soundsOn,
            screensaver: screensaver,
            screensaverTimeout: screensaverTimeout,
            screensaverSound: plist["screensaverSound"] as? Bool ?? Choices.standard.screensaverSound
        )
    }

    public func save(_ choices: Choices) throws {
        let wallpaper: [String: String] = switch choices.wallpaper {
        case .color(let hex): ["kind": "color", "hex": hex]
        case .picture(let path, let name): ["kind": "picture", "path": path, "name": name]
        }
        let plist: [String: Any] = [
            "wallpaper": wallpaper,
            "turnedOff": choices.turnedOff.map(\.rawValue).sorted(),
            "soundsOn": choices.soundsOn,
            "screensaver": choices.screensaver.rawValue,
            "screensaverTimeout": choices.screensaverTimeout,
            "screensaverSound": choices.screensaverSound,
        ]
        try files.write(try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0), to: url)
    }

    private static func wallpaper(from dictionary: [String: Any]?) -> WallpaperChoice? {
        switch dictionary?["kind"] as? String {
        case "color": (dictionary?["hex"] as? String).map { .color(hex: $0) }
        case "picture":
            (dictionary?["path"] as? String).map { .picture(path: $0, name: dictionary?["name"] as? String ?? "") }
        default: nil
        }
    }
}

/// Which tweaks a plain `retro98-settings apply` (and so `./install.sh`) applies.
public enum TweakSelection {
    /// The base tweaks, minus the ones turned off in the Control Panel.
    public static func defaultApply(catalog: [Tweak], choices: Choices) -> Set<TweakID> {
        Set(catalog.filter { $0.group == .base }.map(\.id)).subtracting(choices.turnedOff)
    }

    /// The base tweaks a plain apply leaves alone because they're off in the Control Panel, in catalog order.
    public static func skippedByChoice(catalog: [Tweak], choices: Choices) -> [TweakID] {
        catalog.filter { $0.group == .base && choices.turnedOff.contains($0.id) }.map(\.id)
    }
}
