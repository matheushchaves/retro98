import Foundation

public struct TransferRequest: Equatable, Sendable {
    public let kind: FileOperationKind
    public let items: [URL]
    public let destination: URL

    public init(kind: FileOperationKind, items: [URL], destination: URL) {
        self.kind = kind
        self.items = items
        self.destination = destination
    }
}

public enum ConflictChoice: Equatable, Sendable {
    case replace, replaceAll, skip, cancel
}

public struct FileConflict: Equatable, Sendable {
    public let source: URL
    public let existing: URL
    /// Items after this one ("Yes to All" only makes sense when > 0).
    public let remaining: Int

    public init(source: URL, existing: URL, remaining: Int) {
        self.source = source
        self.existing = existing
        self.remaining = remaining
    }
}

/// Bytes while copying; items for everything else.
public struct OperationProgress: Equatable, Sendable {
    public let item: URL
    public let completed: Int64
    public let total: Int64

    public init(item: URL, completed: Int64, total: Int64) {
        self.item = item
        self.completed = completed
        self.total = total
    }
}

/// One top-level effect of an operation, enough to take it back.
public enum FileChange: Equatable, Sendable {
    /// Undo: send to the Trash.
    case created(URL)
    /// Undo: move back to the exact path (also renames and put-backs).
    case moved(from: URL, to: URL)
    /// Undo: put back where it was.
    case trashed(original: URL, trashed: URL)
}

public enum OperationFailure: Equatable, Sendable {
    case cancelled
    /// The destination is the item or inside it.
    case intoItself(URL)
    /// Replacing this item would trash the very item being copied or moved.
    case replacesItsOwnSource(URL)
    case alreadyExists(URL)
    case cannotTrash([URL])
    /// The top-level item and the system's reason.
    case failed(URL, String)
}

public struct OperationOutcome: Equatable, Sendable {
    public var changes: [FileChange]
    public var failure: OperationFailure?

    public init(changes: [FileChange] = [], failure: OperationFailure? = nil) {
        self.changes = changes
        self.failure = failure
    }

    /// Items in their final place (what a window selects afterwards), in order.
    public var results: [URL] {
        changes.compactMap { change in
            switch change {
            case .created(let url), .moved(_, let url): url
            case .trashed: nil
            }
        }
    }
}

public final class OperationControl: @unchecked Sendable {
    private let lock = NSLock()
    private var cancelled = false

    public init() {}

    public func cancel() { lock.withLock { cancelled = true } }
    public var isCancelled: Bool { lock.withLock { cancelled } }
}

/// The file operations, synchronous and blocking: the app runs them off the main thread, tests call them directly.
/// Nothing is ever written over: replaced items go to the Trash first, and a move across volumes removes the
/// source only after the whole item was copied.
public struct FileOperations: Sendable {
    private let environment: ExplorerEnvironment

    public init(environment: ExplorerEnvironment) {
        self.environment = environment
    }

    // MARK: Copy and move

    public func transfer(_ request: TransferRequest, control: OperationControl,
                         resolve: @Sendable (FileConflict) -> ConflictChoice,
                         progress: @Sendable (OperationProgress) -> Void) -> OperationOutcome {
        // copyfile's callback keeps the progress closure only for the duration of this call.
        withoutActuallyEscaping(progress) { progress in
            transfer(request, control: control, resolve: resolve, reporting: progress)
        }
    }

    private func transfer(_ request: TransferRequest, control: OperationControl,
                          resolve: @Sendable (FileConflict) -> ConflictChoice,
                          reporting progress: @escaping @Sendable (OperationProgress) -> Void) -> OperationOutcome {
        let destination = request.destination
        if let item = request.items.first(where: { Self.contains($0, destination) }) {
            return OperationOutcome(failure: .intoItself(item))
        }
        let copies = request.items.filter { needsCopy($0, request) }
        let countsBytes = !copies.isEmpty
        let total = countsBytes ? copies.reduce(0) { $0 + FileCopy.totalSize(of: $1, control: control) } : Int64(request.items.count)
        var completed: Int64 = 0
        var outcome = OperationOutcome()
        var replaceAll = false

        for (index, item) in request.items.enumerated() {
            if control.isCancelled { outcome.failure = .cancelled; break }
            let size = countsBytes && needsCopy(item, request) ? FileCopy.totalSize(of: item, control: control) : 0
            let advance = { (done: Int64) in
                completed += done
                progress(OperationProgress(item: item, completed: completed, total: total))
            }
            let inPlace = Self.parent(of: item) == destination.standardizedFileURL.path
            if request.kind == .move && inPlace { advance(countsBytes ? size : 1); continue }
            var name = item.lastPathComponent
            if request.kind == .copy && inPlace {
                name = FileNames.copyName(for: item, isFolder: Self.isPlainFolder(item), existing: Self.names(in: destination),
                                          languages: environment.languages)
            }
            let target = destination.appending(path: name, directoryHint: .notDirectory)
            if Self.exists(target) {
                if Self.contains(target, item) { outcome.failure = .replacesItsOwnSource(target); break }
                let choice = replaceAll ? .replace : resolve(FileConflict(source: item, existing: target,
                                                                         remaining: request.items.count - index - 1))
                if choice == .cancel { outcome.failure = .cancelled; break }
                if choice == .skip { advance(countsBytes ? size : 1); continue }
                replaceAll = replaceAll || choice == .replaceAll
                do {
                    outcome.changes.append(.trashed(original: target, trashed: try environment.moveToTrash(target)))
                } catch {
                    outcome.failure = .failed(target, error.localizedDescription)
                    break
                }
            }
            if let failure = place(item, at: target, kind: request.kind, control: control,
                                   onBytes: { advance($0) }, changes: &outcome.changes) {
                outcome.failure = failure
                break
            }
            if !countsBytes { advance(1) }
        }
        return outcome
    }

    /// Copies or moves one item to a free `target`; records the change, or returns why it stopped.
    private func place(_ item: URL, at target: URL, kind: FileOperationKind, control: OperationControl,
                       onBytes: @escaping (Int64) -> Void, changes: inout [FileChange]) -> OperationFailure? {
        if kind == .move && environment.isSameVolume(item, target.deletingLastPathComponent()) {
            do {
                try FileManager.default.moveItem(at: item, to: target)
                changes.append(.moved(from: item, to: target))
                return nil
            } catch {
                return .failed(item, error.localizedDescription)
            }
        }
        switch FileCopy.copy(item, to: target, control: control, onBytes: onBytes) {
        case .done:
            guard kind == .move else {
                changes.append(.created(target))
                return nil
            }
            do {
                try FileManager.default.removeItem(at: item)
                changes.append(.moved(from: item, to: target))
                return nil
            } catch {
                changes.append(.created(target))
                return .failed(item, error.localizedDescription)
            }
        case .cancelled:
            try? FileManager.default.removeItem(at: target)
            return .cancelled
        case .failed(let reason):
            try? FileManager.default.removeItem(at: target)
            return .failed(item, reason)
        }
    }

    private func needsCopy(_ item: URL, _ request: TransferRequest) -> Bool {
        request.kind == .copy || !environment.isSameVolume(item, request.destination)
    }

    // MARK: Trash and delete

    /// Items the Trash refuses are reported together, so the app can offer to delete them permanently.
    public func trash(_ items: [URL], control: OperationControl, progress: @Sendable (OperationProgress) -> Void) -> OperationOutcome {
        var outcome = OperationOutcome()
        var refused: [URL] = []
        for (index, item) in items.enumerated() {
            if control.isCancelled { outcome.failure = .cancelled; break }
            do {
                outcome.changes.append(.trashed(original: item, trashed: try environment.moveToTrash(item)))
            } catch {
                if Self.exists(item) { refused.append(item) }
            }
            progress(OperationProgress(item: item, completed: Int64(index + 1), total: Int64(items.count)))
        }
        if outcome.failure == nil && !refused.isEmpty { outcome.failure = .cannotTrash(refused) }
        return outcome
    }

    public func deletePermanently(_ items: [URL], control: OperationControl,
                                  progress: @Sendable (OperationProgress) -> Void) -> OperationOutcome {
        for (index, item) in items.enumerated() {
            if control.isCancelled { return OperationOutcome(failure: .cancelled) }
            do {
                try FileManager.default.removeItem(at: item)
            } catch {
                return OperationOutcome(failure: .failed(item, error.localizedDescription))
            }
            progress(OperationProgress(item: item, completed: Int64(index + 1), total: Int64(items.count)))
        }
        return OperationOutcome()
    }

    // MARK: New folder and rename

    public func newFolder(in folder: URL, languages: [String]) -> OperationOutcome {
        let url = folder.appending(path: FileNames.newFolderName(existing: Self.names(in: folder), languages: languages),
                                   directoryHint: .notDirectory)
        do {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
            return OperationOutcome(changes: [.created(url)])
        } catch {
            return OperationOutcome(failure: .failed(url, error.localizedDescription))
        }
    }

    /// rename(2) in the same folder: a change of case alone works on case-insensitive volumes.
    public func rename(_ item: URL, to name: String) -> OperationOutcome {
        let target = item.deletingLastPathComponent().appending(path: name, directoryHint: .notDirectory)
        if Self.exists(target) && !Self.sameFile(item, target) { return OperationOutcome(failure: .alreadyExists(target)) }
        guard Darwin.rename(item.path, target.path) == 0 else {
            return OperationOutcome(failure: .failed(item, FileCopy.reason(errno: errno)))
        }
        return OperationOutcome(changes: [.moved(from: item, to: target)])
    }

    // MARK: Revert

    /// Takes changes back in reverse order and stops at the first problem; the outcome lists what it did.
    public func revert(_ changes: [FileChange], control: OperationControl,
                       progress: @Sendable (OperationProgress) -> Void) -> OperationOutcome {
        var outcome = OperationOutcome()
        for (index, change) in changes.reversed().enumerated() {
            if control.isCancelled { outcome.failure = .cancelled; break }
            let failure: OperationFailure?
            switch change {
            case .created(let url):
                if Self.exists(url) {
                    do {
                        outcome.changes.append(.trashed(original: url, trashed: try environment.moveToTrash(url)))
                        failure = nil
                    } catch {
                        failure = .failed(url, error.localizedDescription)
                    }
                } else {
                    failure = .failed(url, FileCopy.reason(errno: ENOENT))
                }
            case .moved(let from, let to):
                failure = moveBack(to, to: from, control: control, changes: &outcome.changes)
            case .trashed(let original, let trashed):
                failure = moveBack(trashed, to: original, control: control, changes: &outcome.changes)
            }
            if let failure { outcome.failure = failure; break }
            progress(OperationProgress(item: changes[changes.count - 1 - index].item, completed: Int64(index + 1), total: Int64(changes.count)))
        }
        return outcome
    }

    /// Moves `item` to the exact path `target`, recreating missing parent folders.
    private func moveBack(_ item: URL, to target: URL, control: OperationControl, changes: inout [FileChange]) -> OperationFailure? {
        guard Self.exists(item) else { return .failed(item, FileCopy.reason(errno: ENOENT)) }
        if Self.exists(target) {
            guard Self.sameFile(item, target) else { return .alreadyExists(target) }
            guard Darwin.rename(item.path, target.path) == 0 else { return .failed(item, FileCopy.reason(errno: errno)) }
            changes.append(.moved(from: item, to: target))
            return nil
        }
        do {
            try FileManager.default.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
        } catch {
            return .failed(item, error.localizedDescription)
        }
        return place(item, at: target, kind: .move, control: control, onBytes: { _ in }, changes: &changes)
    }

    // MARK: Paths

    /// Exists without following links (a broken link is still in the way).
    static func exists(_ url: URL) -> Bool {
        var info = stat()
        return lstat(url.path, &info) == 0
    }

    static func sameFile(_ a: URL, _ b: URL) -> Bool {
        var first = stat(), second = stat()
        guard lstat(a.path, &first) == 0, lstat(b.path, &second) == 0 else { return false }
        return first.st_dev == second.st_dev && first.st_ino == second.st_ino
    }

    /// `inner` is `outer` or inside it.
    static func contains(_ outer: URL, _ inner: URL) -> Bool {
        let outerPath = outer.standardizedFileURL.path, innerPath = inner.standardizedFileURL.path
        return innerPath == outerPath || innerPath.hasPrefix(outerPath == "/" ? "/" : outerPath + "/")
    }

    static func parent(of url: URL) -> String { url.standardizedFileURL.deletingLastPathComponent().path }

    static func names(in folder: URL) -> Set<String> {
        Set((try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? [])
    }

    static func isPlainFolder(_ url: URL) -> Bool {
        let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isPackageKey])
        return values?.isDirectory == true && values?.isPackage != true
    }
}

extension FileChange {
    /// The item this change is about, where it is now.
    var item: URL {
        switch self {
        case .created(let url), .moved(_, let url): url
        case .trashed(_, let trashed): trashed
        }
    }
}
