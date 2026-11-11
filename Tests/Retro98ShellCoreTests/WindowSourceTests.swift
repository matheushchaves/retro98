import Testing
@testable import Retro98ShellCore

@Test func snapshotSkipsAppsThatFail() {
    struct Boom: Error {}
    let windows = WindowCollector.collect(apps: [
        { [snap(1)] }, { throw Boom() }, { [snap(2), snap(3)] },
    ])
    #expect(windows.map(\.id) == [1, 2, 3])
}

@Test func collectingNoAppsGivesNoWindows() {
    #expect(WindowCollector.collect(apps: [() throws -> [WindowSnapshot<Int>]]()).isEmpty)
}
