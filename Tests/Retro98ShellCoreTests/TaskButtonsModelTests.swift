import Testing
@testable import Retro98ShellCore

final class FakeWindowSource: WindowSource {
    var windows: [WindowSnapshot<Int>] = []
    var reads = 0

    func snapshot() -> [WindowSnapshot<Int>] {
        reads += 1
        return windows
    }
}

final class FakeWindowCommands: WindowCommands {
    var calls: [String] = []
    var succeeds = true

    func activate(_ id: Int) -> Bool { record("activate(\(id))") }
    func minimize(_ id: Int) -> Bool { record("minimize(\(id))") }
    func close(_ id: Int) -> Bool { record("close(\(id))") }

    private func record(_ call: String) -> Bool {
        calls.append(call)
        return succeeds
    }
}

@MainActor @Test func clickActivatesOrMinimizesThroughCommands() {
    let source = FakeWindowSource()
    source.windows = [snap(1, focused: true), snap(2)]
    let commands = FakeWindowCommands()
    let model = TaskButtonsModel(source: source, commands: commands)
    model.refresh()

    model.click(1)
    model.click(2)

    #expect(commands.calls == ["minimize(1)", "activate(2)"])
}

@MainActor @Test func clickOnVanishedWindowRefreshesInsteadOfActing() {
    let source = FakeWindowSource()
    source.windows = [snap(1), snap(2)]
    let commands = FakeWindowCommands()
    let model = TaskButtonsModel(source: source, commands: commands)
    model.refresh()

    commands.succeeds = false
    source.windows = [snap(2)]
    model.click(1)

    #expect(model.windows.map(\.id) == [2])
    model.click(99)                               // not on the taskbar at all
    #expect(!commands.calls.contains("activate(99)"))
}

@MainActor @Test func refreshKeepsOrderAcrossUpdates() {
    let source = FakeWindowSource()
    source.windows = [snap(1), snap(2)]
    let model = TaskButtonsModel(source: source, commands: FakeWindowCommands())
    model.refresh()
    source.windows = [snap(2), snap(1), snap(3)]
    model.refresh()
    #expect(model.windows.map(\.id) == [1, 2, 3])
}

@MainActor @Test func onChangeFiresOnlyWhenWindowsChange() {
    let source = FakeWindowSource()
    source.windows = [snap(1)]
    let model = TaskButtonsModel(source: source, commands: FakeWindowCommands())
    var changes = 0
    model.onChange = { changes += 1 }
    model.refresh()
    model.refresh()
    #expect(changes == 1)
}

@MainActor @Test func menuCommandsReachTheWindow() {
    let source = FakeWindowSource()
    source.windows = [snap(1, minimized: true)]
    let commands = FakeWindowCommands()
    let model = TaskButtonsModel(source: source, commands: commands)
    model.refresh()
    model.restore(1)
    model.minimize(1)
    model.close(1)
    #expect(commands.calls == ["activate(1)", "minimize(1)", "close(1)"])
}
