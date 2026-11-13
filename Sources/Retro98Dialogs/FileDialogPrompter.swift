import AppKit
import Retro98UI

/// The questions and warnings of the open and save dialogs (tests answer from a script).
@MainActor
public protocol FileDialogPrompter: AnyObject {
    /// True for Yes.
    func confirmReplace(_ message: String, title: String, languages: [String]) -> Bool
    func tell(_ message: String, title: String, icon: MessageBoxIcon, languages: [String])
}

/// The live prompter: modal 98-style message boxes.
@MainActor
public final class RetroFileDialogPrompter: FileDialogPrompter {
    public init() {}

    public func confirmReplace(_ message: String, title: String, languages: [String]) -> Bool {
        RetroMessageBox.run(title: title, message: message, icon: .warning,
                            buttons: [FileDialogText.yes(languages), FileDialogText.no(languages)]) == 0
    }

    public func tell(_ message: String, title: String, icon: MessageBoxIcon, languages: [String]) {
        _ = RetroMessageBox.run(title: title, message: message, icon: icon, buttons: ["OK"])
    }
}
