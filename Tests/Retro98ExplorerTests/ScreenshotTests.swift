import AppKit
import Testing
@testable import Retro98Explorer
@testable import Retro98FilesCore
import Retro98UI

/// The Explorer on a made-up Desktop, for the README (never the real one).
@MainActor @Test(.enabled(if: screenshotFolder != nil), arguments: ["en", "pt-BR"])
func screenshotExplorer(language: String) throws {
    let isPortuguese = language.hasPrefix("pt")
    let names = isPortuguese ? ["Projetos", "Fotos", "Músicas", "notas.txt", "ideias.txt", "lista de compras.txt"]
        : ["Projects", "Photos", "Music", "notes.txt", "ideas.txt", "shopping list.txt"]
    let home = try TempTree(names.map { "Desktop/\($0)" } + ["Documents", "Downloads", ".Trash"])
    let environment = ExplorerEnvironment(home: home.root, languages: [language], showHidden: false,
                                          volumes: { [VolumeInfo(url: URL(filePath: "/"), name: "Macintosh HD", kind: .internal,
                                                                 totalBytes: 494_000_000_000, freeBytes: 212_000_000_000,
                                                                 isEjectable: false)] },
                                          trash: home.root.appending(path: ".Trash"))
    let controller = ExplorerWindowController(start: .desktop, languages: [language], environment: environment)
    try saveScreenshot(of: controller.window, as: "explorer", language: language)
}
