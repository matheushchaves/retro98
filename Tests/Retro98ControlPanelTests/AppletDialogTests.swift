import AppKit
import Testing
@testable import Retro98ControlPanel
import Retro98Settings

@MainActor @Test func okAppliesAndClosesCancelDoesNot() {
    var applied = 0, closed = 0
    let dialog = AppletDialog(title: "Teste", contentSize: CGSize(width: 200, height: 100), languages: pt)
    dialog.onApply = { applied += 1 }
    dialog.onClose = { closed += 1 }
    dialog.performOK()
    #expect(applied == 1 && closed == 1)
    dialog.performCancel()
    #expect(applied == 1 && closed == 2)
    #expect(dialog.buttonTitles == ["OK", "Cancelar", "Aplicar"])
}

@MainActor @Test func applyKeepsDialogOpen() {
    var applied = 0, closed = 0
    let dialog = AppletDialog(title: "Teste", contentSize: CGSize(width: 200, height: 100), languages: pt)
    dialog.onApply = { applied += 1 }
    dialog.onClose = { closed += 1 }
    dialog.performApply()
    #expect(applied == 1 && closed == 0)
}

private let appearanceIDs: [TweakID] = [.lightAppearance, .colors, .contrast, .scrollBars, .windowAnimations, .titleBarDoubleClick,
                                        .finderExplorer]

@MainActor @Test func appearanceListsSevenTweaksWithState() throws {
    let services = TestServices()
    let model = ControlPanelModel(services: services)
    _ = model.setTweaks(on: [.colors], off: [])
    let applet = TweakListApplet.appearance(model: model, services: services, prompter: ScriptedPrompter())

    #expect(applet.boxes.map(\.id) == appearanceIDs)
    #expect(applet.boxes.map(\.box.title) == appearanceIDs.map(model.title(of:)))
    #expect(applet.boxes.filter(\.box.isOn).map(\.id) == [.colors])

    applet.box(.colors)?.performClick()
    applet.box(.scrollBars)?.performClick()
    applet.dialog.performOK()

    let managed = try model.managed()
    #expect(managed.contains(.scrollBars))
    #expect(!managed.contains(.colors))
}

@MainActor @Test func mouseListsPointer() {
    let services = TestServices()
    let applet = TweakListApplet.mouse(model: ControlPanelModel(services: services), services: services, prompter: ScriptedPrompter())
    #expect(applet.boxes.map(\.id) == [.pointer])
}

@MainActor @Test func displayPicksColorFromSwatches() {
    let services = TestServices()
    let applet = DisplayApplet(model: ControlPanelModel(services: services), services: services, prompter: ScriptedPrompter())
    #expect(applet.swatches.map(\.hex) == DisplayApplet.colors)
    #expect(DisplayApplet.colors == ["#008080", "#000080", "#008000", "#800000", "#800080", "#808000", "#808080", "#C0C0C0",
                                     "#000000", "#FFFFFF", "#0000FF", "#00FF00", "#FF0000", "#FF00FF", "#FFFF00", "#00FFFF"])
    #expect(applet.macOSOption.isSelected)

    applet.clickSwatch(3)
    #expect(applet.colorOption.isSelected && !applet.macOSOption.isSelected)
    applet.dialog.performOK()

    #expect(services.wallpaper.hexes == ["#800000"])
}

@MainActor @Test func displayRefusesNonImage() throws {
    let folder = FileManager.default.temporaryDirectory.appending(path: "retro98-display-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: folder) }
    let notes = folder.appending(path: "notas.txt")
    try Data("texto".utf8).write(to: notes)
    let services = TestServices()
    let prompter = ScriptedPrompter()
    let applet = DisplayApplet(model: ControlPanelModel(services: services), services: services, prompter: prompter,
                               pickPicture: { notes })

    applet.browse()

    #expect(prompter.shown.last?.message == "\"notas.txt\" não é uma imagem que o macOS consiga abrir.")
    #expect(applet.macOSOption.isSelected)
    applet.dialog.performOK()
    #expect(services.wallpaper.hexes.isEmpty && services.wallpaper.pictures.isEmpty)
}

@MainActor @Test func soundsAppletPreviewsEachSound() throws {
    let services = TestServices()
    try services.choices.save(Choices.standard.with(soundsOn: false))
    let applet = SoundsApplet(model: ControlPanelModel(services: services), services: services, prompter: ScriptedPrompter())
    #expect(applet.rows.map(\.kind) == [.startup, .error, .warning, .emptyTrash, .alert])
    #expect(applet.rows.map(\.title) == ["Início do Retro98", "Erro", "Aviso", "Esvaziar a Lixeira", "Alerta"])
    #expect(!applet.soundsBox.isOn)
    applet.rows[1].play.performClick()
    #expect(services.previewed == [.error])
}

@MainActor @Test func soundsAppletAppliesBothSwitches() throws {
    let services = TestServices()
    let model = ControlPanelModel(services: services)
    let applet = SoundsApplet(model: model, services: services, prompter: ScriptedPrompter())
    #expect(applet.soundsBox.isOn && !applet.alertBox.isOn)
    applet.soundsBox.performClick()
    applet.alertBox.performClick()
    applet.dialog.performOK()
    #expect(services.choices.load().soundsOn == false)
    #expect(try model.managed().contains(.alertSound))
}

@MainActor @Test func componentsDisablesMissingPieces() {
    let services = TestServices()
    services.fakeShell.isInstalled = false
    services.explorerInstalled = false
    let applet = ComponentsApplet(model: ControlPanelModel(services: services), services: services, prompter: ScriptedPrompter())
    #expect(applet.taskbarBox.title == "Barra de tarefas e menu Iniciar")
    #expect(!applet.taskbarBox.isEnabled && !applet.taskbarNote.isHidden)
    #expect(!applet.fileViewerBox.isEnabled && !applet.fileViewerNote.isHidden)
    #expect(applet.menuBarBox.isEnabled)
    #expect(applet.taskbarNote.lines.joined(separator: " ") == "Não instalado: rode ./install.sh para instalar.")

    let installed = TestServices()
    let shown = ComponentsApplet(model: ControlPanelModel(services: installed), services: installed, prompter: ScriptedPrompter())
    #expect(shown.taskbarBox.isEnabled && shown.taskbarNote.isHidden)
}

@MainActor @Test func componentsAppletTurnsTheTaskbarOn() throws {
    let services = TestServices()
    try services.pieces.save(Pieces(line: "base shelloff prompt"))
    let model = ControlPanelModel(services: services)
    let applet = ComponentsApplet(model: model, services: services, prompter: ScriptedPrompter())
    #expect(!applet.taskbarBox.isOn)
    applet.taskbarBox.performClick()
    applet.menuBarBox.performClick()
    applet.dialog.performOK()
    #expect(services.fakeShell.turnOnCalls == 1)
    #expect(try model.managed().contains(.hiddenMenuBar))
}
