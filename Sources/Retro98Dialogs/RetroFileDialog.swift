import AppKit
import Retro98FilesCore

/// The retro open and save dialogs, for any Retro98 app.
public enum RetroFileDialog {
    /// Shows the dialog modally in `folder` with `fileName` in the name field; the chosen file, or nil when cancelled.
    @MainActor
    public static func run(mode: FileDialogMode, folder: URL, fileName: String, filters: [FileTypeFilter],
                           languages: [String]) -> URL? {
        let dialog = FileDialogController(mode: mode, folder: folder, fileName: fileName, filters: filters, languages: languages)
        dialog.onFinish = { NSApp.stopModal() }
        dialog.window.showCentered()
        dialog.nameField.focus(in: dialog.window)
        NSApp.runModal(for: dialog.window)
        dialog.window.orderOut(nil)
        return dialog.result
    }
}
