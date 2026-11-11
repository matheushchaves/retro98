import Testing
import Retro98Settings
@testable import Retro98ShellCore

final class RecordingRunner: CommandRunner {
    var runs: [[String]] = []
    var exitCode: Int32 = 0

    func run(_ executable: String, _ arguments: [String]) -> Int32 {
        runs.append([executable] + arguments)
        return exitCode
    }
}

@Test func powerActionRunsSystemEventsCommand() {
    let runner = RecordingRunner()
    #expect(PowerAction.restart.perform(runner: runner))
    #expect(runner.runs == [["/usr/bin/osascript", "-e", "tell application \"System Events\" to restart"]])
    #expect(PowerAction.allCases.map(\.appleScriptCommand) == ["shut down", "restart", "log out", "sleep"])
}

@Test func powerActionReportsFailureWhenOsascriptFails() {
    let runner = RecordingRunner()
    runner.exitCode = 1
    #expect(!PowerAction.shutDown.perform(runner: runner))
}

@Test func powerActionTitles() {
    #expect(PowerAction.allCases.map { $0.title(languages: ["pt-BR"]) } == ["Desligar", "Reiniciar", "Encerrar sessão", "Repouso"])
    #expect(PowerAction.allCases.map { $0.title(languages: ["en"]) } == ["Shut down", "Restart", "Log out", "Sleep"])
}
