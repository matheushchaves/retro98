import AppKit
import Retro98UI
import Testing
@testable import Retro98Notepad

/// The Notepad with a short text, for the README.
@MainActor @Test(.enabled(if: screenshotFolder != nil), arguments: ["en", "pt-BR"])
func screenshotNotepad(language: String) throws {
    VGAFont.register(at: vgaFontURL)
    let folder = try temporaryFolder()
    defer { try? FileManager.default.removeItem(at: folder) }
    let isPortuguese = language.hasPrefix("pt")
    let file = folder.appending(path: isPortuguese ? "leia-me.txt" : "readme.txt")
    let text = isPortuguese ? """
    Retro98 - Bloco de Notas
    ========================

    Texto puro, na fonte VGA dos PCs antigos.

    - UTF-8, com acentos: ação, coração, pão de queijo
    - Mantém as quebras de linha do arquivo
    - F5 insere a hora e a data
    - Localizar com Command+F

    C:\\> _
    """ : """
    Retro98 - Notepad
    =================

    Plain text, in the VGA font of old PCs.

    - UTF-8, accents included: ação, coração, déjà vu
    - Keeps the file's own line endings
    - F5 inserts the time and date
    - Find with Command+F

    C:\\> _
    """
    try Data(text.utf8).write(to: file)
    let controller = NotepadWindowController(
        languages: [language], preferences: .memory(), dialogs: ScriptedNotepadDialogs(), prompter: ScriptedNotepadPrompter(),
        startFolder: { folder }, folderUsed: { _ in }
    )
    #expect(controller.load(file))
    var frame = controller.window.frame
    frame.size = CGSize(width: 560, height: 360)
    controller.window.setFrame(frame, display: true)
    try saveScreenshot(of: controller.window, as: "notepad", language: language)
}
