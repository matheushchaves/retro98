import AppKit
import Testing
@testable import Retro98ControlPanel

@MainActor @Test func windowShowsEveryApplet() {
    let controller = ControlPanelWindowController(services: TestServices(), prompter: ScriptedPrompter())
    #expect(controller.window.title == "Painel de Controle")
    #expect(controller.numberOfItems(in: controller.grid) == 11)
    #expect((0..<11).map { controller.grid(controller.grid, titleAt: $0) } == Applet.allCases.map { $0.title(pt) })
}

@MainActor @Test func statusBarDescribesSelection() {
    let controller = ControlPanelWindowController(services: TestServices(), prompter: ScriptedPrompter())
    #expect(controller.statusBar.fields.first?.text == "11 objeto(s)")
    controller.grid.setSelection(IndexSet(integer: 0))
    #expect(controller.statusBar.fields.first?.text == Applet.display.description(pt))
    controller.grid.setSelection(IndexSet())
    #expect(controller.statusBar.fields.first?.text == "11 objeto(s)")
}

@MainActor @Test func openingMacOSShortcutOpensSettings() {
    let services = TestServices()
    let controller = ControlPanelWindowController(services: services, prompter: ScriptedPrompter())
    controller.open(.keyboard)
    #expect(services.opened == [Applet.keyboard.settingsURL!])
}

@MainActor @Test func openingRetroAppletAsksForItsDialog() {
    let services = TestServices()
    let controller = ControlPanelWindowController(services: services, prompter: ScriptedPrompter())
    var asked: [Applet] = []
    controller.onOpenApplet = { asked.append($0) }
    controller.open(.sounds)
    #expect(asked == [.sounds])
    #expect(services.opened.isEmpty)
}

@MainActor @Test func appMenuHasAboutSettingsQuit() {
    let menu = ControlPanelMenus.mainMenu(languages: pt)
    let items = menu.items.first?.submenu?.items ?? []
    #expect(items.contains { $0.action == #selector(AppDelegate.showAbout(_:)) })
    #expect(items.contains { $0.keyEquivalent == "," && $0.action == #selector(AppDelegate.showWindow(_:)) })
    #expect(items.contains { $0.action == #selector(NSApplication.terminate(_:)) })
}

@MainActor @Test func backToNormalAsksFirst() throws {
    let services = TestServices()
    services.fakeShell.isOn = true
    let prompter = ScriptedPrompter()
    let controller = ControlPanelWindowController(services: services, prompter: prompter)
    controller.presentsDialogs = false
    controller.openDialog(.display)
    #expect(controller.dialogs.count == 1)

    prompter.answers = [1]
    controller.backToNormal(nil)
    #expect(services.fakeShell.turnOffCalls == 0)
    #expect(prompter.shown.first?.icon == .question)
    #expect(prompter.shown.first?.buttons == ["Voltar ao normal", "Cancelar"])

    prompter.answers = [0, 0]
    controller.backToNormal(nil)
    #expect(services.fakeShell.turnOffCalls == 1)
    #expect(prompter.shown.last?.message == "Pronto: o macOS voltou ao normal. Para remover os apps do Retro98, rode ./uninstall.sh.")
    #expect(controller.dialogs.isEmpty)
}
