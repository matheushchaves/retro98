import AppKit
import Retro98Dialogs
import Retro98UI

enum SaveAnswer: Equatable {
    case save, discard, cancel
}

/// The Notepad's questions and warnings (tests answer from a script).
@MainActor
protocol NotepadPrompter: AnyObject {
    /// "The text has changed. Save the changes?" with Yes, No and Cancel.
    func askToSave(_ message: String, languages: [String]) -> SaveAnswer
    func tell(_ message: String, icon: MessageBoxIcon, languages: [String])
}

/// Where to open from and save to (tests hand out files instead of showing dialogs).
@MainActor
protocol NotepadDialogs: AnyObject {
    func chooseFileToOpen(in folder: URL, languages: [String]) -> URL?
    func chooseSaveLocation(in folder: URL, name: String, languages: [String]) -> URL?
}

/// The live prompter: modal 98-style message boxes titled "Notepad".
@MainActor
final class RetroNotepadPrompter: NotepadPrompter {
    func askToSave(_ message: String, languages l: [String]) -> SaveAnswer {
        let buttons = [NotepadText.yes(l), NotepadText.no(l), NotepadText.cancel(l)]
        switch RetroMessageBox.run(title: NotepadText.name(l), message: message, icon: .warning, buttons: buttons) {
        case 0: return .save
        case 1: return .discard
        default: return .cancel
        }
    }

    func tell(_ message: String, icon: MessageBoxIcon, languages l: [String]) {
        _ = RetroMessageBox.run(title: NotepadText.name(l), message: message, icon: icon, buttons: ["OK"])
    }
}

/// The live dialogs: the retro open and save dialogs, listing text files first.
@MainActor
final class RetroNotepadDialogs: NotepadDialogs {
    func chooseFileToOpen(in folder: URL, languages: [String]) -> URL? {
        RetroFileDialog.run(mode: .open, folder: folder, fileName: "", filters: NotepadText.filters(languages), languages: languages)
    }

    func chooseSaveLocation(in folder: URL, name: String, languages: [String]) -> URL? {
        RetroFileDialog.run(mode: .save, folder: folder, fileName: name, filters: NotepadText.filters(languages), languages: languages)
    }
}
