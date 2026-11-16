import Foundation
import Testing
@testable import Retro98ControlPanel
import Retro98Settings

@MainActor
@Test func screensaverAppletDialogHasOKAndApplyButtons() {
    let services = TestServices()
    let p = ScriptedPrompter()
    let applet = ScreensaverApplet(model: ControlPanelModel(services: services), services: services, prompter: p)
    #expect(applet.dialog.buttonTitles.contains("OK"))
    #expect(applet.dialog.buttonTitles.contains(ControlPanelText.apply(["pt-BR"])))
}

@MainActor
@Test func screensaverAppletSelectingPipesSavesChoice() throws {
    let services = TestServices()
    let p = ScriptedPrompter()
    let applet = ScreensaverApplet(model: ControlPanelModel(services: services), services: services, prompter: p)
    applet.select(.pipes)
    applet.applyForTesting()
    #expect(services.choices.load().screensaver == .pipes)
}

@MainActor
@Test func screensaverAppletSelectingNoneSavesNone() throws {
    let services = TestServices()
    let p = ScriptedPrompter()
    let applet = ScreensaverApplet(model: ControlPanelModel(services: services), services: services, prompter: p)
    applet.select(.none)
    applet.applyForTesting()
    #expect(services.choices.load().screensaver == .none)
}

@MainActor
@Test func screensaverAppletSelectingJohnnySavesJohnny() throws {
    let services = TestServices()
    let p = ScriptedPrompter()
    let applet = ScreensaverApplet(model: ControlPanelModel(services: services), services: services, prompter: p)
    applet.select(.johnny)
    applet.applyForTesting()
    #expect(services.choices.load().screensaver == .johnny)
}

@MainActor
@Test func screensaverAppletTimeoutDropdownSavesTimeout() throws {
    let services = TestServices()
    let p = ScriptedPrompter()
    let applet = ScreensaverApplet(model: ControlPanelModel(services: services), services: services, prompter: p)
    applet.selectTimeout(10)
    applet.applyForTesting()
    #expect(services.choices.load().screensaverTimeout == 10)
}

@MainActor
@Test func screensaverAppletLoadsCurrentChoices() {
    let services = TestServices()
    try? services.choices.save(Choices.standard.with(screensaver: ScreensaverKind.text3d).with(screensaverTimeout: 15))
    let p = ScriptedPrompter()
    let applet = ScreensaverApplet(model: ControlPanelModel(services: services), services: services, prompter: p)
    #expect(applet.selectedKind == .text3d)
    #expect(applet.selectedTimeout == 15)
}
