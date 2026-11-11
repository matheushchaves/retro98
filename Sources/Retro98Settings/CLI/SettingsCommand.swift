public enum SettingsCommandError: Error, Equatable {
    case usage
    case unknownTweak(String)
}

/// `retro98-settings <status | apply | restore> [--only id1,id2]`
public enum SettingsCommand: Equatable, Sendable {
    case status
    case apply(only: Set<TweakID>?)
    case restore(only: Set<TweakID>?)

    /// Parses the arguments after the program name.
    public static func parse(_ arguments: [String]) throws(SettingsCommandError) -> SettingsCommand {
        guard let verb = arguments.first else { throw .usage }
        let options = Array(arguments.dropFirst())
        switch verb {
        case "status":
            guard options.isEmpty else { throw .usage }
            return .status
        case "apply":
            return .apply(only: try parseOnly(options))
        case "restore":
            return .restore(only: try parseOnly(options))
        default:
            throw .usage
        }
    }

    private static func parseOnly(_ options: [String]) throws(SettingsCommandError) -> Set<TweakID>? {
        guard !options.isEmpty else { return nil }
        guard options.count == 2, options[0] == "--only" else { throw .usage }
        let names = options[1].split(separator: ",").map(String.init)
        guard !names.isEmpty else { throw .usage }

        var ids: Set<TweakID> = []
        for name in names {
            guard let id = TweakID(rawValue: name) else { throw .unknownTweak(name) }
            ids.insert(id)
        }
        return ids
    }
}

/// 0 when every selected tweak succeeded, 2 when any failed.
public func exitStatus(for report: EngineReport) -> Int32 {
    report.failed.isEmpty ? 0 : 2
}
