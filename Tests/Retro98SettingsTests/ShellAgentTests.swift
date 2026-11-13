import Foundation
import Testing
@testable import Retro98Settings

private let label = "io.github.matheushchaves.retro98.shell"
private let paths = Retro98Paths.standard(home: URL(filePath: "/Users/ana"), environment: [
    "RETRO98_APPS_DIR": "/tmp/a", "RETRO98_LAUNCH_AGENTS_DIR": "/tmp/l",
])

private final class Recorder: CommandRunner {
    var events: [String] = []
    var commands: [[String]] = []
    var bootstrapStatus: Int32 = 0
    /// `launchctl print` succeeds only for a loaded service.
    var loaded = true

    func run(_ executable: String, _ arguments: [String]) -> Int32 {
        guard arguments.first != "print" else { return loaded ? 0 : 113 }
        commands.append([executable] + arguments)
        events.append(arguments.first ?? executable)
        switch arguments.first {
        case "bootstrap": return bootstrapStatus
        default: return 0
        }
    }
}

private func agent(_ recorder: Recorder, files: InMemoryFileStore = InMemoryFileStore(), installed: Bool = true) -> ShellAgent {
    ShellAgent(paths: paths, files: files, runner: recorder, uid: 501, exists: { _ in installed },
               stopCopies: { recorder.events.append("stopCopies") })
}

@Test func plistMatchesInstaller() throws {
    let data = try ShellAgent.plist(executable: "/A/Retro98 Shell.app/Contents/MacOS/Retro98Shell")
    let plist = try #require(try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])
    #expect(plist["Label"] as? String == label)
    #expect(plist["ProgramArguments"] as? [String] == ["/A/Retro98 Shell.app/Contents/MacOS/Retro98Shell"])
    #expect(plist["RunAtLoad"] as? Bool == true)
    #expect(plist["KeepAlive"] as? [String: Bool] == ["SuccessfulExit": false])
    #expect(plist["ThrottleInterval"] as? Int == 5)
    #expect(plist["ProcessType"] as? String == "Interactive")
    #expect(ShellAgent.label == label)
}

@Test func turnOnEnablesBeforeBootstrap() throws {
    let recorder = Recorder()
    let files = InMemoryFileStore()
    let shell = agent(recorder, files: files)
    #expect(!shell.isOn)
    try shell.turnOn()
    #expect(try files.read(paths.launchAgentPlist) != nil)
    #expect(shell.isOn)
    #expect(recorder.commands == [
        ["/bin/launchctl", "bootout", "gui/501/\(label)"],
        ["/bin/launchctl", "enable", "gui/501/\(label)"],
        ["/bin/launchctl", "bootstrap", "gui/501", paths.launchAgentPlist.path],
    ])
    // A copy opened outside launchd would make a second taskbar: it stops before the agent starts.
    #expect(recorder.events == ["bootout", "stopCopies", "enable", "bootstrap"])
}

@Test func givenUpShellIsOff() throws {
    let recorder = Recorder()
    let files = InMemoryFileStore()
    let shell = agent(recorder, files: files)
    try shell.turnOn()
    // Crash recovery disables and boots out the agent but leaves its plist.
    recorder.loaded = false
    #expect(!shell.isOn)
    recorder.loaded = true
    #expect(shell.isOn)
}

@Test func turnOffStopsCopiesAndRemovesAgent() throws {
    let recorder = Recorder()
    let files = InMemoryFileStore()
    let shell = agent(recorder, files: files)
    try shell.turnOn()
    shell.turnOff()
    #expect(recorder.commands.last == ["/bin/launchctl", "bootout", "gui/501/\(label)"])
    #expect(recorder.events.suffix(2) == ["bootout", "stopCopies"])
    #expect(try files.read(paths.launchAgentPlist) == nil)
    #expect(!shell.isOn)
}

@Test func turnOffTwiceIsHarmless() {
    let recorder = Recorder()
    let shell = agent(recorder)
    shell.turnOff()
    shell.turnOff()
    #expect(recorder.events == ["bootout", "stopCopies", "bootout", "stopCopies"])
}

@Test func turnOnFailsWhenNotInstalled() {
    let recorder = Recorder()
    let shell = agent(recorder, installed: false)
    #expect(!shell.isInstalled)
    #expect(throws: ShellAgentError.notInstalled) { try shell.turnOn() }
    #expect(recorder.commands.isEmpty)
}

@Test func bootstrapFailureIsReported() throws {
    let recorder = Recorder()
    recorder.bootstrapStatus = 5
    let files = InMemoryFileStore()
    #expect(throws: ShellAgentError.launchctlFailed(5)) { try agent(recorder, files: files).turnOn() }
    #expect(try files.read(paths.launchAgentPlist) != nil)
}

@Test func appPathsFollowOverrides() {
    #expect(paths.shellApp.path == "/tmp/a/Retro98 Shell.app")
    #expect(paths.explorerApp.path == "/tmp/a/Retro98 Explorer.app")
    #expect(paths.controlPanelApp.path == "/tmp/a/Retro98 Control Panel.app")
    #expect(paths.launchAgentPlist.path == "/tmp/l/\(label).plist")
    let standard = Retro98Paths.standard(home: URL(filePath: "/Users/ana"), environment: [:])
    #expect(standard.shellApp.path == "/Users/ana/Applications/Retro98/Retro98 Shell.app")
    #expect(standard.launchAgentPlist.path == "/Users/ana/Library/LaunchAgents/\(label).plist")
    #expect(standard.piecesFile.path == "/Users/ana/Library/Application Support/Retro98/pieces")
}
