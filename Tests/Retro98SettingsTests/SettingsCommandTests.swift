import Testing
@testable import Retro98Settings

@Test func parsesCommands() throws {
    #expect(try SettingsCommand.parse(["status"]) == .status)
    #expect(try SettingsCommand.parse(["apply"]) == .apply(only: nil))
    #expect(try SettingsCommand.parse(["apply", "--only", "colors,pointer"]) == .apply(only: [.colors, .pointer]))
    #expect(try SettingsCommand.parse(["restore", "--only", "wallpaper"]) == .restore(only: [.wallpaper]))
}

@Test func rejectsBadArguments() {
    #expect(throws: SettingsCommandError.usage) { try SettingsCommand.parse([]) }
    #expect(throws: SettingsCommandError.usage) { try SettingsCommand.parse(["apply", "--only"]) }
    #expect(throws: SettingsCommandError.usage) { try SettingsCommand.parse(["status", "--only", "colors"]) }
    #expect(throws: SettingsCommandError.usage) { try SettingsCommand.parse(["explode"]) }
    #expect(throws: SettingsCommandError.unknownTweak("nope")) { try SettingsCommand.parse(["apply", "--only", "nope"]) }
}

@Test func exitStatusIsTwoWhenAnyTweakFailed() {
    #expect(exitStatus(for: EngineReport(succeeded: [.colors], failed: [], warnings: [])) == 0)
    #expect(exitStatus(for: EngineReport(
        succeeded: [], failed: [TweakFailure(id: .contrast, reason: .writeDenied([]))], warnings: []
    )) == 2)
}
