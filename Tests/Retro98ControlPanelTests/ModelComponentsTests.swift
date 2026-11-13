import Foundation
import Testing
@testable import Retro98ControlPanel
import Retro98Settings

private let beepKey = PreferenceKey(domain: .global, name: "com.apple.sound.beep.sound")
private let dockAutohide = PreferenceKey(domain: .app("com.apple.dock"), name: "autohide")
private let fileViewerKey = PreferenceKey(domain: .global, name: "NSFileViewer")

@MainActor @Test func soundsSwitchIsSaved() {
    let services = TestServices()
    let model = ControlPanelModel(services: services)
    #expect(model.soundsOn())
    #expect(model.setSounds(on: false).isEmpty)
    #expect(services.choices.load().soundsOn == false)
    #expect(!model.soundsOn())
}

@MainActor @Test func alertSoundWritesFileThenApplies() throws {
    let services = TestServices()
    let model = ControlPanelModel(services: services)

    #expect(model.setAlertSound(on: true).isEmpty)
    #expect(services.events == ["writeAlertSound"])
    #expect(services.alertSoundExists)
    #expect(services.store.value(for: beepKey) == .string("/sounds/Retro98.aiff"))

    #expect(model.setAlertSound(on: false).isEmpty)
    #expect(services.store.value(for: beepKey) == nil)
    #expect(!services.alertSoundExists)
    #expect(services.events == ["writeAlertSound", "removeAlertSound"])
}

@MainActor @Test func alertSoundFileFailureChangesNothing() {
    let services = TestServices()
    services.alertSoundError = TestError()
    let model = ControlPanelModel(services: services)
    let problems = model.setAlertSound(on: true)
    #expect(problems.count == 1)
    if case .fileFailed = problems.first {} else { Issue.record("expected fileFailed, got \(problems)") }
    #expect(services.store.snapshot.isEmpty)
}

@MainActor @Test func taskbarOffStopsAgentRestoresDockAndMarksShelloff() throws {
    let services = TestServices(preferences: [dockAutohide: .bool(false)])
    try services.pieces.save(Pieces(line: "base shell prompt"))
    let model = ControlPanelModel(services: services)
    _ = model.setTweaks(on: [.dockUnderTaskbar], off: [])
    services.fakeShell.isOn = true

    #expect(model.setTaskbar(on: false).isEmpty)

    #expect(services.fakeShell.turnOffCalls == 1)
    #expect(services.store.value(for: dockAutohide) == .bool(false))
    #expect(services.pieces.load().line == "base shelloff prompt")
    #expect(try model.components().taskbar == .off)
}

@MainActor @Test func taskbarOnAppliesDockStartsAgentAndMarksShell() throws {
    let services = TestServices(preferences: [dockAutohide: .bool(false)])
    try services.pieces.save(Pieces(line: "base shelloff prompt"))
    var dockWhenStarting: PreferenceValue?
    services.fakeShell.onTurnOn = { dockWhenStarting = services.store.value(for: dockAutohide) }
    let model = ControlPanelModel(services: services)

    #expect(model.setTaskbar(on: true).isEmpty)

    #expect(dockWhenStarting == .bool(true))
    #expect(services.fakeShell.turnOnCalls == 1)
    #expect(services.pieces.load().line == "base shell prompt")
    #expect(try model.components().taskbar == .on)
}

@MainActor @Test func taskbarThatFailsToStartGivesTheDockBack() throws {
    let services = TestServices(preferences: [dockAutohide: .bool(false)])
    try services.pieces.save(Pieces(line: "base shelloff prompt"))
    services.fakeShell.turnOnError = ShellAgentError.launchctlFailed(5)
    let model = ControlPanelModel(services: services)

    let problems = model.setTaskbar(on: true)

    #expect(problems.count == 1)
    if case .shellFailed = problems.first {} else { Issue.record("expected shellFailed, got \(problems)") }
    #expect(services.store.value(for: dockAutohide) == .bool(false))
    #expect(services.pieces.load().line == "base shelloff prompt")
}

@MainActor @Test func taskbarNotInstalledIsReported() throws {
    let services = TestServices()
    services.fakeShell.isInstalled = false
    let model = ControlPanelModel(services: services)
    #expect(model.setTaskbar(on: true) == [.shellNotInstalled])
    #expect(services.fakeShell.turnOnCalls == 0)
    #expect(services.store.snapshot.isEmpty)
    #expect(try model.components().taskbar == .notInstalled)
}

@MainActor @Test func fileViewerFollowsPieces() throws {
    let services = TestServices()
    try services.pieces.save(Pieces(line: "base shell prompt"))
    let model = ControlPanelModel(services: services)

    #expect(model.setFileViewer(on: true).isEmpty)
    #expect(services.store.value(for: fileViewerKey) == .string("io.github.matheushchaves.retro98.explorer"))
    #expect(services.pieces.load().line == "base shell prompt fileviewer")
    #expect(try model.components().fileViewer == .on)

    #expect(model.setFileViewer(on: false).isEmpty)
    #expect(services.store.value(for: fileViewerKey) == nil)
    #expect(services.pieces.load().line == "base shell prompt")
    services.explorerInstalled = false
    #expect(try model.components().fileViewer == .notInstalled)
}

@MainActor @Test func backToNormalRestoresEverything() throws {
    let services = TestServices(preferences: machineLike)
    try services.pieces.save(Pieces(line: "base shell fileviewer prompt"))
    let model = ControlPanelModel(services: services)
    let base = Set(services.catalog().filter { $0.group == .base }.map(\.id))
    _ = model.setTweaks(on: base.union([.dockUnderTaskbar, .explorerFileViewer, .hiddenMenuBar]), off: [])
    _ = model.setAlertSound(on: true)
    services.fakeShell.isOn = true
    #expect(try model.managed().count == base.count + 4)

    #expect(model.backToNormal().isEmpty)

    #expect(services.store.snapshot == machineLike)
    #expect(services.fakeShell.turnOffCalls == 1)
    // "base" leaves the pieces (so --yes keeps macOS normal and an interactive "Yes" brings them back);
    // the tweaks the person turned off one by one stay as they were.
    #expect(services.pieces.load().line == "shelloff prompt")
    #expect(!services.alertSoundExists)
    #expect(services.choices.load().turnedOff.isEmpty)
    #expect(try model.managed().isEmpty)
}

@MainActor @Test func backToNormalStopsALooseTaskbar() throws {
    let services = TestServices()
    try services.pieces.save(Pieces(line: "base shell prompt"))
    services.fakeShell.isOn = false   // gave up after crashing, or opened outside launchd
    let model = ControlPanelModel(services: services)

    #expect(model.backToNormal().isEmpty)

    #expect(services.fakeShell.turnOffCalls == 1)
    #expect(services.pieces.load().line == "shelloff prompt")
}

@MainActor @Test func backToNormalWithUnreadableBackupChangesNothing() throws {
    let services = TestServices()
    try services.pieces.save(Pieces(line: "base shell fileviewer prompt"))
    try services.files.write(Data("lixo".utf8), to: services.paths.backupFile)
    services.fakeShell.isOn = true
    let model = ControlPanelModel(services: services)

    #expect(model.backToNormal() == [.backupUnreadable(path: "/s/backup.plist")])

    #expect(services.fakeShell.turnOffCalls == 0)
    #expect(services.pieces.load().line == "base shell fileviewer prompt")
    #expect(services.choices.load() == .standard)
}

@MainActor @Test func backToNormalWithoutShellInstalled() throws {
    let services = TestServices(preferences: machineLike)
    services.fakeShell.isInstalled = false
    try services.pieces.save(Pieces(line: "base prompt"))
    let model = ControlPanelModel(services: services)
    _ = model.setTweaks(on: [.pointer, .scrollBars], off: [])

    #expect(model.backToNormal().isEmpty)

    #expect(services.store.snapshot == machineLike)
    #expect(services.fakeShell.turnOffCalls == 0)
    #expect(services.pieces.load().line == "prompt")
}

/// A few of the person's own values, so restoring has something to put back.
let machineLike: [PreferenceKey: PreferenceValue] = [
    PreferenceKey(domain: .global, name: "AppleInterfaceStyle"): .string("Dark"),
    PreferenceKey(domain: .app("com.apple.dock"), name: "tilesize"): .int(48),
    PreferenceKey(domain: .global, name: "AppleShowScrollBars"): .string("Automatic"),
]
