import Testing
@testable import Retro98ShellCore

/// Only the copy started by the LaunchAgent may draw the taskbar: uninstall stops that one, and
/// System Settings' "Quit & Reopen", the Start menu or Finder would otherwise leave an orphan or a second taskbar.
@Test func onlyTheLaunchAgentCopyRunsTheTaskbar() {
    let label = ShellIdentity.label
    #expect(ShellLaunch.role(serviceName: label, agentInstalled: true, otherCopyRunning: true) == .runTaskbar)
    #expect(ShellLaunch.role(serviceName: "application.\(label).49655478.49655500", agentInstalled: true, otherCopyRunning: false)
            == .handOverToLaunchAgent)
    #expect(ShellLaunch.role(serviceName: nil, agentInstalled: true, otherCopyRunning: true) == .handOverToLaunchAgent)
    // Not installed (run from a build folder): still never two taskbars.
    #expect(ShellLaunch.role(serviceName: "0", agentInstalled: false, otherCopyRunning: false) == .runTaskbar)
    #expect(ShellLaunch.role(serviceName: "0", agentInstalled: false, otherCopyRunning: true) == .quitAsDuplicate)
}

@Test func handingOverStartsTheLaunchAgent() {
    #expect(ShellIdentity.handOverCommand(uid: 501) == ["/bin/launchctl", "kickstart", "gui/501/io.github.matheushchaves.retro98.shell"])
}
