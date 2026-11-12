import Foundation
import Retro98FilesCore

/// Shows the app's file undo history to AppKit: every Explorer window returns this as its undo
/// manager, so Edit › Undo, ⌘Z and the menu titles ("Desfazer Copiar") follow the FileUndoStack.
/// Nothing registers with it; undo and redo run asynchronously through `perform`.
/// `isBlocked` turns it off while a window edits text: a text field keeps the window's undo manager
/// as its fallback from the moment editing starts, so ⌘Z after the typing history runs out lands here.
@MainActor
final class ExplorerUndoManager: UndoManager {
    private let stack: FileUndoStack
    private let languages: [String]
    private let perform: @MainActor (_ redo: Bool) -> Void
    private let isBlocked: @MainActor () -> Bool

    init(stack: FileUndoStack, languages: [String], isBlocked: @escaping @MainActor () -> Bool = { false },
         perform: @escaping @MainActor (_ redo: Bool) -> Void) {
        self.stack = stack
        self.languages = languages
        self.isBlocked = isBlocked
        self.perform = perform
        super.init()
    }

    override var canUndo: Bool { !isBlocked() && stack.canUndo }
    override var canRedo: Bool { !isBlocked() && stack.canRedo }

    override func undo() {
        guard canUndo else { return }
        perform(false)
    }

    override func redo() {
        guard canRedo else { return }
        perform(true)
    }

    override var undoActionName: String { stack.undoName.map { ExplorerText.actionName($0, languages) } ?? "" }
    override var redoActionName: String { stack.redoName.map { ExplorerText.actionName($0, languages) } ?? "" }
    override var undoMenuItemTitle: String { ExplorerText.undoTitle(stack.undoName, languages) }
    override var redoMenuItemTitle: String { ExplorerText.redoTitle(stack.redoName, languages) }
}
