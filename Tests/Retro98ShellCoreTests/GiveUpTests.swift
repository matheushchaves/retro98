import Testing
@testable import Retro98ShellCore

@Test func givingUpDisablesTheAgentSoItStaysOffAfterLogin() {
    #expect(ShellIdentity.giveUpCommands(uid: 501) == [
        ["/bin/launchctl", "disable", "gui/501/io.github.matheushchaves.retro98.shell"],
        ["/bin/launchctl", "bootout", "gui/501/io.github.matheushchaves.retro98.shell"],
    ])
}
