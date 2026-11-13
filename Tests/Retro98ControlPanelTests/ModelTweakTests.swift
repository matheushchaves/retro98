import Foundation
import Testing
@testable import Retro98ControlPanel
import Retro98Settings

let cursorFill = PreferenceKey(domain: .app("com.apple.universalaccess"), name: "cursorFill")
let cursorCustomized = PreferenceKey(domain: .app("com.apple.universalaccess"), name: "cursorIsCustomized")

@MainActor @Test func turningOnAppliesAndForgetsTurnedOff() throws {
    let services = TestServices()
    try services.choices.save(Choices.standard.turning(.pointer, on: false))
    let model = ControlPanelModel(services: services)

    #expect(model.setTweaks(on: [.pointer], off: []).isEmpty)

    #expect(services.store.value(for: cursorCustomized) == .bool(true))
    #expect(try model.managed().contains(.pointer))
    #expect(services.choices.load().turnedOff.isEmpty)
}

@MainActor @Test func turningOffRestoresAndRemembers() throws {
    let services = TestServices(preferences: [cursorCustomized: .bool(false)])
    let model = ControlPanelModel(services: services)
    _ = model.setTweaks(on: [.pointer], off: [])

    #expect(model.setTweaks(on: [], off: [.pointer]).isEmpty)

    #expect(services.store.value(for: cursorCustomized) == .bool(false))
    #expect(services.store.value(for: cursorFill) == nil)
    #expect(try !model.managed().contains(.pointer))
    #expect(services.choices.load().turnedOff == [.pointer])
}

@MainActor @Test func extraTweaksAreNotRememberedAsTurnedOff() throws {
    let services = TestServices()
    let model = ControlPanelModel(services: services)
    #expect(model.setTweaks(on: [.hiddenMenuBar], off: []).isEmpty)
    #expect(model.setTweaks(on: [], off: [.hiddenMenuBar]).isEmpty)
    #expect(services.choices.load().turnedOff.isEmpty)
}

@MainActor @Test func deniedAccessibilityAsksForFullDiskAccess() throws {
    let services = TestServices(deniedKeys: [cursorFill])
    let model = ControlPanelModel(services: services)

    let problems = model.setTweaks(on: [.pointer], off: [])

    #expect(problems == [.failed(TweakFailure(id: .pointer, reason: .writeDenied([cursorFill])))])
    #expect(services.store.value(for: cursorCustomized) == nil)
    #expect(try !model.managed().contains(.pointer))
    #expect(services.choices.load() == .standard)
    let report = try #require(ControlPanelText.problems(problems, model: model, languages: pt))
    #expect(report.offersFullDiskAccess)
    #expect(report.icon == .error)
    #expect(report.message.contains("Não foi possível mudar: Ponteiro branco com contorno preto."))
    #expect(report.message.contains("Acesso Total ao Disco ao Retro98 Control Panel"))
}

@MainActor @Test func unreadableBackupChangesNothing() throws {
    let services = TestServices()
    try services.files.write(Data("lixo".utf8), to: services.paths.backupFile)
    let model = ControlPanelModel(services: services)

    #expect(model.setTweaks(on: [.pointer], off: []) == [.backupUnreadable(path: "/s/backup.plist")])
    #expect(services.store.snapshot.isEmpty)
    let report = try #require(ControlPanelText.problems([.backupUnreadable(path: "/s/backup.plist")], model: model, languages: pt))
    #expect(report.message == "O backup dos ajustes está ilegível (/s/backup.plist). Nada foi mudado.")
    #expect(!report.offersFullDiskAccess)
    #expect(ControlPanelText.problems([], model: model, languages: pt) == nil)
}
