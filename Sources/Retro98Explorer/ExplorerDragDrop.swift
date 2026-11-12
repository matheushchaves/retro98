import AppKit
import Retro98FilesCore
import Retro98UI

/// What a drop does: copy or move into a folder, or send to the Recycle Bin (asking first).
enum DropPlan: Equatable {
    case transfer(FileOperationKind, into: URL)
    case trash
}

/// Files promised by other apps (Photos, Mail) are written here, off the main thread.
@MainActor private let promiseQueue: OperationQueue = {
    let queue = OperationQueue()
    queue.qualityOfService = .userInitiated
    return queue
}()

/// Dragging out carries file URLs (the Finder and other apps take them as they are);
/// dropping in follows the Finder: same disk moves, another disk copies, ⌥ copies, ⌘ moves.
extension ExplorerWindowController: RetroIconGridDropDelegate {
    func grid(_ grid: RetroIconGrid, pasteboardWriterAt index: Int) -> NSPasteboardWriting? {
        let entry = model.entries[index]
        return entry.isFileItem ? entry.url as NSURL : nil
    }

    /// The item under the pointer when it can take the drop (a folder, My Documents, a disk, the
    /// Recycle Bin); otherwise the place the window shows. nil = nothing to do here.
    func dropPlan(for urls: [URL], onItem index: Int?, forceCopy: Bool, forceMove: Bool) -> DropPlan? {
        guard !urls.isEmpty, let target = dropTarget(onItem: index).target else { return nil }
        switch target {
        case .trash:
            return urls.allSatisfy { $0.standardizedFileURL.path.hasPrefix(environment.trash.standardizedFileURL.path + "/") } ? nil : .trash
        case .folder(let destination):
            return DropRules.operation(sources: urls, destination: destination, sameVolume: environment.isSameVolume(urls[0], destination),
                                       forceCopy: forceCopy, forceMove: forceMove).map { .transfer($0, into: destination) }
        }
    }

    /// The window asks and selects what landed in the folder it shows.
    func performDrop(_ plan: DropPlan, urls: [URL]) async -> [URL] {
        switch plan {
        case .trash:
            await operations.trash(urls)
            model.reload()
            return []
        case .transfer(let kind, let destination):
            let results = await operations.transfer(urls, kind: kind, into: destination)
            if destination.standardizedFileURL.path == destinationFolder?.standardizedFileURL.path {
                showResults(results)
            } else {
                model.reload()
            }
            return results
        }
    }

    // MARK: RetroIconGridDropDelegate

    func grid(_ grid: RetroIconGrid, validateDrop info: NSDraggingInfo, onItem index: Int?) -> RetroIconGrid.DropResponse {
        let none = RetroIconGrid.DropResponse(operation: [], highlightsItem: false)
        let urls = Self.fileURLs(info)
        let onItem = dropTarget(onItem: index).isItem
        if urls.isEmpty {
            guard Self.hasPromises(info), promiseDestination(onItem: index) != nil else { return none }
            return RetroIconGrid.DropResponse(operation: .copy, highlightsItem: onItem)
        }
        let forces = Self.forces(info.draggingSourceOperationMask)
        switch dropPlan(for: urls, onItem: index, forceCopy: forces.copy, forceMove: forces.move) {
        case nil: return none
        case .trash: return RetroIconGrid.DropResponse(operation: .move, highlightsItem: onItem)
        case .transfer(let kind, _): return RetroIconGrid.DropResponse(operation: kind == .copy ? .copy : .move, highlightsItem: onItem)
        }
    }

    func grid(_ grid: RetroIconGrid, acceptDrop info: NSDraggingInfo, onItem index: Int?) -> Bool {
        let urls = Self.fileURLs(info)
        guard !urls.isEmpty else { return receivePromises(info, onItem: index) }
        let forces = Self.forces(info.draggingSourceOperationMask)
        guard let plan = dropPlan(for: urls, onItem: index, forceCopy: forces.copy, forceMove: forces.move) else { return false }
        spawn { [weak self] in _ = await self?.performDrop(plan, urls: urls) }
        return true
    }

    // MARK: Helpers

    private func dropTarget(onItem index: Int?) -> (target: DropTarget?, isItem: Bool) {
        let location = model.history.current
        if let index, model.entries.indices.contains(index),
           let target = DropRules.target(entry: model.entries[index], at: location, home: environment.home, trash: environment.trash) {
            return (target, true)
        }
        return (DropRules.target(entry: nil, at: location, home: environment.home, trash: environment.trash), false)
    }

    private func promiseDestination(onItem index: Int?) -> URL? {
        guard case .folder(let url)? = dropTarget(onItem: index).target else { return nil }
        return url
    }

    /// Promised files arrive without undo or questions: the promising app names them.
    private func receivePromises(_ info: NSDraggingInfo, onItem index: Int?) -> Bool {
        guard let destination = promiseDestination(onItem: index),
              let receivers = info.draggingPasteboard.readObjects(forClasses: [NSFilePromiseReceiver.self]) as? [NSFilePromiseReceiver],
              !receivers.isEmpty else { return false }
        for receiver in receivers {
            receiver.receivePromisedFiles(atDestination: destination, options: [:], operationQueue: promiseQueue) { [weak self] _, _ in
                DispatchQueue.main.async { MainActor.assumeIsolated { self?.model.reload() } }
            }
        }
        return true
    }

    private static func fileURLs(_ info: NSDraggingInfo) -> [URL] {
        (info.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL]) ?? []
    }

    private static func hasPromises(_ info: NSDraggingInfo) -> Bool {
        info.draggingPasteboard.canReadObject(forClasses: [NSFilePromiseReceiver.self], options: nil)
    }

    /// ⌥ leaves only "copy" in the source's mask; ⌘ leaves only "move" (or "generic").
    private static func forces(_ mask: NSDragOperation) -> (copy: Bool, move: Bool) {
        let canMove = mask.contains(.move) || mask.contains(.generic)
        return (copy: mask.contains(.copy) && !canMove, move: canMove && !mask.contains(.copy))
    }
}
