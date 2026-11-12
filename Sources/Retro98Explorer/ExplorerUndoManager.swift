import Foundation
import Retro98FilesCore

/// Shows the app's file undo history to AppKit: every Explorer window returns this as its undo
/// manager, so Edit › Undo, ⌘Z and the menu titles ("Desfazer Copiar") follow the FileUndoStack.
/// Nothing registers with it; undo and redo run asynchronously through `perform`.
@MainActor
final class ExplorerUndoManager: UndoManager {
    private let stack: FileUndoStack
    private let languages: [String]
    private let perform: @MainActor (_ redo: Bool) -> Void

    init(stack: FileUndoStack, languages: [String], perform: @escaping @MainActor (_ redo: Bool) -> Void) {
        self.stack = stack
        self.languages = languages
        self.perform = perform
        super.init()
    }

    override var canUndo: Bool { stack.canUndo }
    override var canRedo: Bool { stack.canRedo }
    override func undo() { perform(false) }
    override func redo() { perform(true) }
    override var undoActionName: String { stack.undoName.map { ExplorerText.actionName($0, languages) } ?? "" }
    override var redoActionName: String { stack.redoName.map { ExplorerText.actionName($0, languages) } ?? "" }
    override var undoMenuItemTitle: String { ExplorerText.undoTitle(stack.undoName, languages) }
    override var redoMenuItemTitle: String { ExplorerText.redoTitle(stack.redoName, languages) }
}
