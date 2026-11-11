import Foundation
import Testing
import Retro98Settings
@testable import Retro98ShellCore

private let historyURL = URL(filePath: "/support/shell-launches.plist")
private let t0 = Date(timeIntervalSince1970: 1_000_000)

@Test func givesUpAfterThreeLaunchesWithinSixtySeconds() throws {
    let history = LaunchHistory(url: historyURL, files: InMemoryFileStore())
    #expect(try history.recordLaunch(now: t0) == false)
    #expect(try history.recordLaunch(now: t0 + 10) == false)
    #expect(try history.recordLaunch(now: t0 + 20) == true)
}

@Test func oldLaunchesFallOutOfTheWindow() throws {
    let history = LaunchHistory(url: historyURL, files: InMemoryFileStore())
    #expect(try history.recordLaunch(now: t0) == false)
    #expect(try history.recordLaunch(now: t0 + 50) == false)
    #expect(try history.recordLaunch(now: t0 + 120) == false)
}

@Test func cleanExitClearsHistory() throws {
    let files = InMemoryFileStore()
    let history = LaunchHistory(url: historyURL, files: files)
    _ = try history.recordLaunch(now: t0)
    _ = try history.recordLaunch(now: t0 + 1)
    try history.recordCleanExit()
    #expect(files.snapshot[historyURL] == nil)
    #expect(try history.recordLaunch(now: t0 + 2) == false)
}

@Test func corruptHistoryCountsAsEmpty() throws {
    let files = InMemoryFileStore([historyURL: Data("garbage".utf8)])
    let history = LaunchHistory(url: historyURL, files: files)
    #expect(try history.recordLaunch(now: t0) == false)
    #expect(try PropertyListDecoder().decode([Date].self, from: #require(files.snapshot[historyURL])) == [t0])
}

@Test func shellIdentityMatchesInstaller() {
    #expect(ShellIdentity.label == "io.github.matheushchaves.retro98.shell")
    #expect(ShellIdentity.launchHistoryFileName == "shell-launches.plist")
}
