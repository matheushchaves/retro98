import Foundation
import Retro98Settings

let fullDiskAccessSettingsURL = "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles"
let universalAccessDomain = PreferenceDomain.app("com.apple.universalaccess")

let messages = Messages(languages: Locale.preferredLanguages)
let system = SystemEngine.make()
let paths = system.paths
let catalog = system.catalog
let engine = system.engine

func printError(_ message: String) {
    FileHandle.standardError.write(Data((message + "\n").utf8))
}

func title(of id: TweakID) -> String {
    let tweak = catalog.first { $0.id == id }
    return "\(tweak?.title.resolve(for: messages.languages) ?? id.rawValue) (\(id.rawValue))"
}

func printStatus(_ statuses: [TweakStatus]) {
    for status in statuses {
        let mark = switch status.state {
        case .applied: "[x]"
        case .partial: "[~]"
        case .notApplied: "[ ]"
        }
        print("\(mark) \(title(of: status.id))")
    }
}

func printReport(_ report: EngineReport, restoring: Bool) {
    if report.succeeded.isEmpty && report.failed.isEmpty && restoring {
        print(messages.nothingToRestore)
    }
    for id in report.succeeded {
        print("  \(messages.ok.padding(toLength: 7, withPad: " ", startingAt: 0)) \(title(of: id))")
    }
    for failure in report.failed {
        print("  \(messages.failed.padding(toLength: 7, withPad: " ", startingAt: 0)) \(title(of: failure.id))")
    }
    let deniedAccessibility = report.failed.contains { failure in
        guard case .writeDenied(let keys) = failure.reason else { return false }
        return keys.contains { $0.domain == universalAccessDomain }
    }
    if deniedAccessibility {
        print(messages.accessibilityDenied)
        _ = ProcessCommandRunner().run("/usr/bin/open", [fullDiskAccessSettingsURL])
    }
    if report.warnings.contains(.appearanceNeedsLogout) {
        print(messages.appearanceNeedsLogout)
    }
}

let command: SettingsCommand
do {
    command = try SettingsCommand.parse(Array(CommandLine.arguments.dropFirst()))
} catch SettingsCommandError.unknownTweak(let name) {
    printError(messages.unknownTweak(name))
    printError(messages.usage)
    exit(1)
} catch {
    printError(messages.usage)
    exit(1)
}

do {
    switch command {
    case .status:
        printStatus(try engine.status())
        exit(0)
    case .apply(let only):
        // Without --only, apply the base tweaks; Shell tweaks are applied by the installer.
        let baseTweaks = Set(catalog.filter { $0.group == .base }.map(\.id))
        let report = try engine.apply(only ?? baseTweaks)
        printReport(report, restoring: false)
        exit(exitStatus(for: report))
    case .restore(let only):
        let report = try engine.restore(only)
        printReport(report, restoring: true)
        exit(exitStatus(for: report))
    }
} catch is BackupError {
    printError(messages.unreadableBackup(paths.backupFile.path))
    exit(3)
} catch {
    printError(messages.unexpected(error))
    exit(2)
}
