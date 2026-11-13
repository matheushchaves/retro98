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
