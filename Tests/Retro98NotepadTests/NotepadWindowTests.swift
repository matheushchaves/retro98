import AppKit
import Retro98UI
import Testing
@testable import Retro98Notepad

/// A Notepad window wired to scripted dialogs and questions, with a throwaway folder for its files.
@MainActor private final class Desk {
    let root: URL
    let prompter = ScriptedNotepadPrompter()
    let dialogs = ScriptedNotepadDialogs()
    var foldersUsed: [URL] = []
    private(set) var controller: NotepadWindowController!

    init(wordWrap: Bool = false) throws {
        VGAFont.register(at: vgaFontURL)
        root = try temporaryFolder()
        controller = NotepadWindowController(
            languages: ["pt-BR"], preferences: .memory(wordWrap: wordWrap), dialogs: dialogs, prompter: prompter,
            startFolder: { [root] in root }, folderUsed: { [weak self] in self?.foldersUsed.append($0) }
        )
    }

    func file(_ name: String, _ bytes: Data) throws -> URL {
        let url = root.appending(path: name)
        try bytes.write(to: url)
        return url
    }

    func type(_ text: String) {
        controller.textView.insertText(text, replacementRange: controller.textView.selectedRange())
    }

    deinit {
        try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: root.path)
        try? FileManager.default.removeItem(at: root)
    }
}

@MainActor @Test func textViewIsPlainVGAText() throws {
    let view = try Desk().controller.textView
    #expect(!view.isRichText && view.allowsUndo && view.isEditable)
    #expect(view.font?.fontName == VGAFont.postScriptName)
    #expect(!view.isAutomaticQuoteSubstitutionEnabled && !view.isAutomaticDashSubstitutionEnabled)
    #expect(!view.isAutomaticTextReplacementEnabled && !view.isAutomaticSpellingCorrectionEnabled)
    #expect(!view.isContinuousSpellCheckingEnabled && !view.isAutomaticLinkDetectionEnabled)
    #expect(view.backgroundColor == .white && view.textColor == .black)
}

@MainActor @Test func textIsCrisp() throws {
    VGAFont.register(at: vgaFontURL)
    let view = NotepadTextView(frame: CGRect(x: 0, y: 0, width: 300, height: 40))
    view.string = "ação AÇÃO 123"
    #expect(distinctColors(view, rows: 1) == 2)
}

@MainActor @Test func selectionIsNavyWithWhiteText() throws {
    let attributes = try Desk().controller.textView.selectedTextAttributes
    let background = (attributes[.backgroundColor] as? NSColor)?.usingColorSpace(.sRGB)
    #expect(background?.redComponent == 0 && background?.greenComponent == 0)
    #expect(background.map { Int(($0.blueComponent * 255).rounded()) } == 0x80)
    #expect(attributes[.foregroundColor] as? NSColor == .white)
}

@MainActor @Test func wordWrapFollowsThePreference() throws {
    let controller = try Desk().controller!
    #expect(!controller.wordWrap)
    #expect(controller.textView.textContainer?.widthTracksTextView == false && controller.scrollView.hasHorizontalScroller)
    controller.wordWrap = true
    #expect(controller.textView.textContainer?.widthTracksTextView == true && !controller.scrollView.hasHorizontalScroller)
    #expect(try Desk(wordWrap: true).controller.wordWrap)
}

@MainActor @Test func loadingKeepsTheFilesEnding() throws {
    let desk = try Desk()
    let controller = desk.controller!
    let url = try desk.file("dos.txt", Data("a\r\nb".utf8))
    #expect(controller.load(url))
    #expect(controller.textView.string == "a\nb")
    #expect(controller.window.title == "dos.txt - Bloco de Notas")
    #expect(!controller.isModified && !controller.isUntouched)
    controller.textView.insertText("x", replacementRange: NSRange(location: 3, length: 0))
    #expect(controller.isModified)
    #expect(controller.save())
    #expect(try Data(contentsOf: url) == Data("a\r\nbx".utf8))
    #expect(!controller.isModified)
    #expect(desk.dialogs.saveRequests.isEmpty)
}

@MainActor @Test func loadingNonUTF8TellsAndKeepsTheWindow() throws {
    let desk = try Desk()
    let controller = desk.controller!
    let url = try desk.file("latin1.txt", Data([0x61, 0xE7, 0xE3, 0x6F]))
    #expect(!controller.load(url))
    #expect(desk.prompter.told.last == "Não foi possível abrir latin1.txt: o arquivo não é texto em UTF-8.")
    #expect(controller.fileURL == nil && controller.isUntouched)
    #expect(controller.window.title == "Sem título - Bloco de Notas")
}

@MainActor @Test func loadingClearsUndo() throws {
    let desk = try Desk()
    desk.type("rascunho")
    #expect(desk.controller.load(try desk.file("a.txt", Data("oi".utf8))))
    #expect(desk.controller.textView.undoManager?.canUndo == false)
}

@MainActor @Test func savingUntitledAsksWhere() throws {
    let desk = try Desk()
    let target = desk.root.appending(path: "nota.txt")
    desk.dialogs.saves = [target]
    desk.type("oi")
    #expect(desk.controller.save())
    #expect(try Data(contentsOf: target) == Data("oi".utf8))
    #expect(desk.controller.fileURL == target)
    #expect(desk.dialogs.saveRequests.first?.name == "Sem título.txt")
    #expect(desk.dialogs.saveRequests.first?.folder == desk.root)
    #expect(desk.foldersUsed.last?.path == desk.root.path)
    #expect(desk.controller.window.title == "nota.txt - Bloco de Notas")
}

@MainActor @Test func cancelledSaveAsKeepsChanges() throws {
    let desk = try Desk()
    desk.type("oi")
    #expect(!desk.controller.save())
    #expect(desk.controller.isModified && desk.controller.fileURL == nil)
}

@MainActor @Test func failedSaveTellsAndKeepsChanges() throws {
    let desk = try Desk()
    let url = try desk.file("fixo.txt", Data("antes".utf8))
    #expect(desk.controller.load(url))
    desk.type("novo ")
    try FileManager.default.setAttributes([.posixPermissions: 0o500], ofItemAtPath: desk.root.path)
    #expect(!desk.controller.save())
    #expect(desk.prompter.told.last?.hasPrefix("Não foi possível salvar fixo.txt.") == true)
    #expect(desk.controller.isModified)
    #expect(try Data(contentsOf: url) == Data("antes".utf8))
}

@MainActor @Test func closingModifiedAsks() throws {
    let desk = try Desk()
    let controller = desk.controller!
    let target = desk.root.appending(path: "x.txt")
    desk.type("oi")
    desk.prompter.answers = [.cancel, .discard, .save, .save]
    desk.dialogs.saves = [nil, target]
    #expect(!controller.windowShouldClose(controller.window))
    #expect(desk.prompter.asked.last == "O texto no arquivo Sem título foi alterado.\n\nDeseja salvar as alterações?")
    #expect(controller.windowShouldClose(controller.window))
    #expect(!controller.windowShouldClose(controller.window))
    #expect(controller.windowShouldClose(controller.window))
    #expect(FileManager.default.fileExists(atPath: target.path))
}

@MainActor @Test func closingUnmodifiedDoesNotAsk() throws {
    let desk = try Desk()
    #expect(desk.controller.windowShouldClose(desk.controller.window))
    #expect(desk.prompter.asked.isEmpty)
}

@MainActor @Test func timeDateIsInsertedAndUndoable() throws {
    let desk = try Desk()
    let date = Date(timeIntervalSince1970: 1_794_589_500)
    desk.controller.insertTimeDate(date)
    #expect(desk.controller.textView.string == NotepadText.timeDate(date, locale: .current, timeZone: .current))
    #expect(desk.controller.isModified)
    desk.controller.textView.undoManager?.undo()
    #expect(desk.controller.textView.string == "")
}

@Test func timeDateFormats() throws {
    let date = Date(timeIntervalSince1970: 1_794_589_500)
    let zone = try #require(TimeZone(identifier: "America/Sao_Paulo"))
    #expect(NotepadText.timeDate(date, locale: Locale(identifier: "pt_BR"), timeZone: zone) == "14:05 13/11/2026")
    #expect(NotepadText.timeDate(date, locale: Locale(identifier: "en_US"), timeZone: zone) == "2:05\u{202F}PM 11/13/26")
}

@Test func titlesAndMessagesFollowTheLanguage() {
    #expect(NotepadText.windowTitle(fileName: nil, ["en"]) == "Untitled - Notepad")
    #expect(NotepadText.windowTitle(fileName: "a.txt", ["en"]) == "a.txt - Notepad")
    #expect(NotepadText.untitledFileName(["en"]) == "Untitled.txt")
    #expect(NotepadText.openError(.tooLarge, fileName: "g.log", ["pt-BR"])
        == "Não foi possível abrir g.log: o arquivo passa de 10 MB, o limite do Bloco de Notas.")
    #expect(NotepadText.openError(.notText, fileName: "ls", ["en"]) == "Can't open ls: the file doesn't look like text.")
    #expect(NotepadText.openError(.unreadable, fileName: "x", ["en"]) == "Can't open x: the file couldn't be read.")
    #expect(NotepadText.filters(["pt-BR"]).map(\.extensions) == [["txt"], []])
}
