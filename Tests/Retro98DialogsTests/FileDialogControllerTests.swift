import AppKit
import Retro98FilesCore
import Retro98UI
import Testing
@testable import Retro98Dialogs

/// Answers the replace question from a queue and records every message.
@MainActor private final class ScriptedPrompter: FileDialogPrompter {
    var told: [String] = []
    var asked: [String] = []
    var answers: [Bool] = []

    func confirmReplace(_ message: String, title: String, languages: [String]) -> Bool {
        asked.append(message)
        return answers.isEmpty ? false : answers.removeFirst()
    }

    func tell(_ message: String, title: String, icon: MessageBoxIcon, languages: [String]) { told.append(message) }
}

private let filters = [FileTypeFilter(title: "Documentos de texto (*.txt)", extensions: ["txt"]),
                       FileTypeFilter(title: "Todos os arquivos", extensions: [])]

@MainActor private struct Fixture {
    let tree: TempTree
    let prompter = ScriptedPrompter()
    let dialog: FileDialogController
    var root: String { dialog.folder.path }

    init(mode: FileDialogMode, fileName: String = "", volumes: [VolumeInfo] = []) throws {
        tree = try TempTree(["b.txt", "sub"])
        try Data().write(to: tree.url("c.md"))
        dialog = FileDialogController(mode: mode, folder: tree.root, fileName: fileName, filters: filters, languages: ["pt-BR"],
                                      home: tree.root, volumes: { volumes }, prompter: prompter)
    }
}

@MainActor @Test func listsTheFolderThroughTheFilter() throws {
    let f = try Fixture(mode: .open)
    #expect(f.dialog.entries.map(\.name) == ["sub", "b.txt"])
    f.dialog.chooseFilter(at: 1)
    #expect(f.dialog.entries.map(\.name) == ["sub", "b.txt", "c.md"])
    #expect(f.dialog.typeBox.text == "Todos os arquivos")
}

@MainActor @Test func clickingAFileFillsTheName() throws {
    let f = try Fixture(mode: .open)
    f.dialog.selectionChanged([1])
    #expect(f.dialog.nameField.text == "b.txt")
    f.dialog.selectionChanged([0])
    #expect(f.dialog.nameField.text == "b.txt")
}

@MainActor @Test func typingAFolderOpensIt() throws {
    let f = try Fixture(mode: .open)
    let root = f.root
    f.dialog.nameField.text = "sub"
    f.dialog.submit()
    #expect(f.dialog.folder.path == root + "/sub")
    #expect(f.dialog.nameField.text == "")
    #expect(f.dialog.result == nil)
    #expect(f.dialog.lookIn.text == "sub")
}

@MainActor @Test func openChoosesAnExistingFile() throws {
    let f = try Fixture(mode: .open)
    var finished = 0
    f.dialog.onFinish = { finished += 1 }
    f.dialog.nameField.text = "b.txt"
    f.dialog.submit()
    #expect(f.dialog.result?.path == f.root + "/b.txt")
    #expect(finished == 1)
}

@MainActor @Test func openMissingFileWarnsAndStays() throws {
    let f = try Fixture(mode: .open)
    var finished = 0
    f.dialog.onFinish = { finished += 1 }
    f.dialog.nameField.text = "x.txt"
    f.dialog.submit()
    #expect(f.prompter.told.last?.contains("x.txt") == true)
    #expect(f.prompter.told.last?.contains("Arquivo não encontrado") == true)
    #expect(f.dialog.result == nil && finished == 0)
}

@MainActor @Test func activatingAFolderOpensItAndAFileChoosesIt() throws {
    let f = try Fixture(mode: .open)
    let root = f.root
    f.dialog.activate(itemAt: 0)
    #expect(f.dialog.folder.path == root + "/sub")
    f.dialog.goUp()
    f.dialog.activate(itemAt: 1)
    #expect(f.dialog.result?.path == root + "/b.txt")
}

@MainActor @Test func saveAddsTheTypesExtension() throws {
    let f = try Fixture(mode: .save)
    f.dialog.nameField.text = "nota"
    f.dialog.submit()
    #expect(f.dialog.result?.path == f.root + "/nota.txt")
}

@MainActor @Test func saveOverExistingFileAsks() throws {
    let f = try Fixture(mode: .save, fileName: "b.txt")
    #expect(f.dialog.nameField.text == "b.txt")
    f.prompter.answers = [false, true]
    f.dialog.submit()
    #expect(f.dialog.result == nil)
    #expect(f.prompter.asked.last == "b.txt já existe.\nDeseja substituí-lo?")
    f.dialog.submit()
    #expect(f.dialog.result?.path == f.root + "/b.txt")
}

@MainActor @Test func saveKeepsTheTypedNameWhenOpeningAFolder() throws {
    let f = try Fixture(mode: .save)
    let root = f.root
    f.dialog.nameField.text = "nota"
    f.dialog.activate(itemAt: 0)
    #expect(f.dialog.folder.path == root + "/sub")
    #expect(f.dialog.nameField.text == "nota")
}

@MainActor @Test func saveRefusesBadNamesAndMissingFolders() throws {
    let f = try Fixture(mode: .save)
    f.dialog.nameField.text = "a:b"
    f.dialog.submit()
    #expect(f.prompter.told.last == "a:b\nO nome do arquivo não é válido.")
    f.dialog.nameField.text = "falta/x.txt"
    f.dialog.submit()
    #expect(f.prompter.told.last?.hasSuffix("O caminho não existe.\nVerifique se o caminho está correto.") == true)
    #expect(f.dialog.result == nil)
}

@MainActor @Test func refusedFolderWarnsAndStays() throws {
    let f = try Fixture(mode: .open)
    let root = f.root
    let locked = f.tree.root.appending(path: "trancada")
    try FileManager.default.createDirectory(at: locked, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o000])
    defer { try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: locked.path) }
    #expect(!f.dialog.show(locked))
    #expect(f.dialog.folder.path == root)
    #expect(f.prompter.told.last?.contains("não deu acesso") == true)
}

@MainActor @Test func upGoesToTheParentAndStopsAtRoot() throws {
    let f = try Fixture(mode: .open)
    let root = f.root
    f.dialog.show(f.tree.root.appending(path: "sub"))
    #expect(f.dialog.upButton.isEnabled)
    f.dialog.goUp()
    #expect(f.dialog.folder.path == root)
    f.dialog.show(URL(filePath: "/"))
    #expect(!f.dialog.upButton.isEnabled)
    f.dialog.goUp()
    #expect(f.dialog.folder.path == "/")
}

@MainActor @Test func lookInListsPlacesIndented() throws {
    let disk = VolumeInfo(url: URL(filePath: "/"), name: "Disco", kind: .internal, totalBytes: nil, freeBytes: nil, isEjectable: false)
    let f = try Fixture(mode: .open, volumes: [disk])
    let titles = f.dialog.placeItems().map(\.title)
    let depth = 1 + f.root.split(separator: "/").count
    #expect(titles.first == "Área de Trabalho")
    #expect(titles.contains("  Disco"))
    #expect(titles.contains(String(repeating: "  ", count: depth) + f.tree.root.lastPathComponent))
    #expect(titles.last == "  Meus Documentos")
}

@MainActor @Test func cancelEndsWithNoFile() throws {
    let f = try Fixture(mode: .open)
    var finished = 0
    f.dialog.onFinish = { finished += 1 }
    f.dialog.cancel()
    #expect(f.dialog.result == nil && finished == 1)
}

@MainActor @Test func titlesAndLabelsFollowTheMode() throws {
    let open = try Fixture(mode: .open), save = try Fixture(mode: .save)
    #expect(open.dialog.title == "Abrir" && open.dialog.okButton.title == "Abrir")
    #expect(save.dialog.title == "Salvar como" && save.dialog.okButton.title == "Salvar")
}

@MainActor @Test func unlistableStartFolderFallsBackToHome() throws {
    let tree = try TempTree(["b.txt"])
    let prompter = ScriptedPrompter()
    let dialog = FileDialogController(mode: .open, folder: tree.root.appending(path: "sumiu"), fileName: "", filters: filters,
                                      languages: ["pt-BR"], home: tree.root, volumes: { [] }, prompter: prompter)
    #expect(dialog.folder.path == tree.root.standardizedFileURL.path)
    #expect(prompter.told.isEmpty)
}

@Test func fileKindsMapToIcons() {
    #expect(FileKind.folder.iconKind == .folder && FileKind.text.iconKind == .text)
    #expect(FileKind.volume(.removable).iconKind == .removableDisk)
    #expect(FileKind.recycleBin(isFull: true).iconKind == .recycleBinFull)
}
