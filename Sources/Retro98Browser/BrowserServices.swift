import AppKit
import Retro98Dialogs
import Retro98FilesCore
import Retro98UI

/// What a window gets from the app (tests build it from fakes and memory stores).
@MainActor
struct BrowserServices {
    var makePage: () -> BrowserPage
    var favorites: FavoritesStore
    var history: HistoryStore
    var preferences: BrowserPreferences
    var prompter: BrowserPrompter
    var dialogs: BrowserDialogs
    /// The person's home folder: "~" in typed addresses, and where the open dialog starts.
    var home: URL
    var now: () -> Date
}

/// Commands the windows send up the responder chain for the app to answer.
@MainActor @objc protocol BrowserAppCommands {
    @objc func showHistory(_ sender: Any?)
    @objc func organizeFavorites(_ sender: Any?)
}

/// The live prompter: modal 98-style message boxes titled "Navegador".
@MainActor
final class RetroBrowserPrompter: BrowserPrompter {
    func ask(_ message: String, languages l: [String]) -> Bool {
        RetroMessageBox.run(title: BrowserText.name(l), message: message, icon: .question,
                            buttons: [BrowserText.yes(l), BrowserText.no(l)]) == 0
    }

    func tell(_ message: String, icon: MessageBoxIcon, languages l: [String]) {
        _ = RetroMessageBox.run(title: BrowserText.name(l), message: message, icon: icon, buttons: ["OK"])
    }
}

/// The live dialog: the retro open dialog, listing web pages first.
@MainActor
final class RetroBrowserDialogs: BrowserDialogs {
    func chooseFileToOpen(in folder: URL, languages l: [String]) -> URL? {
        let filters = [FileTypeFilter(title: BrowserText.htmlFiles(l), extensions: ["html", "htm"]),
                       FileTypeFilter(title: BrowserText.allFiles(l), extensions: [])]
        return RetroFileDialog.run(mode: .open, folder: folder, fileName: "", filters: filters, languages: l)
    }
}
