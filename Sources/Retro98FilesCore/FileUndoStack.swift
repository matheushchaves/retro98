import Foundation

public enum FileActionName: Equatable, Sendable {
    case copy, move, rename, newFolder, delete, restore
}

public struct FileAction: Equatable, Sendable {
    public let name: FileActionName
    public let changes: [FileChange]

    public init(name: FileActionName, changes: [FileChange]) {
        self.name = name
        self.changes = changes
    }
}

/// One undo history for the whole app. Undoing reverts an action's changes; redoing reverts what the
/// undo did, so both take the same `revert` function. Nothing runs while an operation is in progress.
@MainActor
public final class FileUndoStack {
    public var onChange: (() -> Void)?
    public private(set) var isBusy = false
    private var work = 0 { didSet { updateBusy() } }
    private var running = false { didSet { updateBusy() } }
    private var undoActions: [FileAction] = []
    private var redoActions: [FileAction] = []

    public init() {}

    public var canUndo: Bool { !isBusy && !undoActions.isEmpty }
    public var canRedo: Bool { !isBusy && !redoActions.isEmpty }
    public var undoName: FileActionName? { undoActions.last?.name }
    public var redoName: FileActionName? { redoActions.last?.name }

    /// Actions that changed nothing are not recorded; a new action clears the redo list.
    public func record(_ action: FileAction) {
        guard !action.changes.isEmpty else { return }
        undoActions.append(action)
        redoActions.removeAll()
        onChange?()
    }

    /// An operation started or ended (undo and redo wait for all of them).
    public func beginWork() { work += 1 }
    public func endWork() { work = max(work - 1, 0) }

    /// nil when there is nothing to undo or something is running.
    public func undo(_ revert: @MainActor ([FileChange]) async -> OperationOutcome) async -> OperationOutcome? {
        guard canUndo, let action = undoActions.popLast() else { return nil }
        let outcome = await run(action, revert)
        if !outcome.changes.isEmpty { redoActions.append(FileAction(name: action.name, changes: outcome.changes)) }
        onChange?()
        return outcome
    }

    public func redo(_ revert: @MainActor ([FileChange]) async -> OperationOutcome) async -> OperationOutcome? {
        guard canRedo, let action = redoActions.popLast() else { return nil }
        let outcome = await run(action, revert)
        if !outcome.changes.isEmpty { undoActions.append(FileAction(name: action.name, changes: outcome.changes)) }
        onChange?()
        return outcome
    }

    public func removeAll() {
        undoActions.removeAll()
        redoActions.removeAll()
        onChange?()
    }

    private func run(_ action: FileAction, _ revert: @MainActor ([FileChange]) async -> OperationOutcome) async -> OperationOutcome {
        running = true
        onChange?()
        defer { running = false }
        return await revert(action.changes)
    }

    private func updateBusy() { isBusy = running || work > 0 }
}
