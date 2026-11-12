import AppKit
import Retro98FilesCore
import Retro98UI

/// The app's one place for changing files, shared by every window: runs the engine off the main
/// thread, asks the questions, shows progress for long operations, records undo and keeps the
/// clipboard. Copy and cut write file URLs to the pasteboard in the same format the Finder uses.
@MainActor
final class ExplorerOperations {
    static let didChange = Notification.Name("Retro98ExplorerOperationsDidChange")

    let environment: ExplorerEnvironment
    let undoStack = FileUndoStack()
    let trashOrigins: TrashOrigins
    let services: ExplorerServices
    private(set) lazy var undoManager = makeUndoManager()

    /// Each window gets its own, turned off while that window edits text.
    func makeUndoManager(isBlocked: @escaping @MainActor () -> Bool = { false }) -> ExplorerUndoManager {
        ExplorerUndoManager(stack: undoStack, languages: environment.languages, isBlocked: isBlocked) { [weak self] redo in
            Task { [weak self] in
                if redo { await self?.redo() } else { await self?.undo() }
            }
        }
    }
    /// For tests: how many progress dialogs appeared, and how many are still on screen.
    private(set) var progressDialogsShown = 0
    private(set) var visibleProgressDialogs = 0
    private let engine: FileOperations
    private let pasteboard: NSPasteboard
    private let prompter: ExplorerPrompter
    private let progressDelay: TimeInterval
    /// Operations in progress (quitting cancels them and waits for their cleanup).
    private var running: [ObjectIdentifier: OperationControl] = [:]
    private var idleWaiters: [CheckedContinuation<Void, Never>] = []
    /// The pasteboard's change count right after a cut; any other copy makes the cut stale.
    private var cutChangeCount: Int?
    private var cutItems: Set<String> = []

    init(environment: ExplorerEnvironment, pasteboard: NSPasteboard = .general, prompter: ExplorerPrompter = RetroPrompter(),
         progressDelay: TimeInterval = 1, services: ExplorerServices = .live) {
        self.environment = environment
        self.services = services
        self.pasteboard = pasteboard
        self.prompter = prompter
        self.progressDelay = progressDelay
        engine = FileOperations(environment: environment)
        trashOrigins = TrashOrigins(file: environment.supportDirectory.appending(path: "trash-origins.json"), trash: environment.trash)
        undoStack.onChange = { [weak self] in self?.postChange() }
    }

    private var languages: [String] { environment.languages }

    /// A question or message from a window (ejecting, for instance), through the same prompter.
    func ask(_ prompt: Prompt) -> Int { prompter.ask(prompt) }

    // MARK: Clipboard

    func copy(_ urls: [URL]) {
        write(urls)
        forgetCut()
    }

    func cut(_ urls: [URL]) {
        write(urls)
        cutChangeCount = pasteboard.changeCount
        cutItems = Set(urls.map(\.standardizedFileURL.path))
        postChange()
    }

    /// Shown ghosted while the pasteboard still holds this cut.
    func isCut(_ url: URL) -> Bool { isCutCurrent && cutItems.contains(url.standardizedFileURL.path) }

    var canPaste: Bool { pasteboard.canReadObject(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) }

    /// Pasting a cut (or forcing a move, ⌥⌘V) moves; anything else copies.
    func paste(into folder: URL, forceMove: Bool = false) async -> [URL] {
        let urls = (pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL]) ?? []
        guard !urls.isEmpty else { return [] }
        let wasCut = isCutCurrent
        let outcome = await runTransfer(urls, kind: forceMove || wasCut ? .move : .copy, into: folder)
        if wasCut && outcome.failure == nil {
            pasteboard.clearContents()
            forgetCut()
        }
        return outcome.results
    }

    /// A drop: the caller already chose copy or move.
    func transfer(_ urls: [URL], kind: FileOperationKind, into folder: URL) async -> [URL] {
        await runTransfer(urls, kind: kind, into: folder).results
    }

    private var isCutCurrent: Bool { cutChangeCount == pasteboard.changeCount }

    private func write(_ urls: [URL]) {
        pasteboard.clearContents()
        pasteboard.writeObjects(urls.map { $0 as NSURL })
    }

    private func forgetCut() {
        cutChangeCount = nil
        cutItems = []
        postChange()
    }

    private func runTransfer(_ urls: [URL], kind: FileOperationKind, into folder: URL) async -> OperationOutcome {
        let request = TransferRequest(kind: kind, items: urls, destination: folder)
        // The engine asks from its background thread and waits for the answer.
        let resolve: @Sendable (FileConflict) -> ConflictChoice = { [weak self] conflict in
            DispatchQueue.main.sync { MainActor.assumeIsolated { self?.resolve(conflict) ?? .cancel } }
        }
        let source = urls.first.map { Self.displayName($0.deletingLastPathComponent()) } ?? ""
        let style = ProgressStyle(title: kind == .copy ? ExplorerText.copying(languages) : ExplorerText.moving(languages),
                                  animation: .folderToFolder,
                                  detail: ExplorerText.fromTo(source, Self.displayName(folder), languages))
        return await run(kind == .copy ? .copy : .move, style: style) { engine, control, progress in
            engine.transfer(request, control: control, resolve: resolve, progress: progress)
        }
    }

    private func resolve(_ conflict: FileConflict) -> ConflictChoice {
        let prompt = Prompts.replace(conflict, existing: Self.summary(of: conflict.existing), incoming: Self.summary(of: conflict.source),
                                     languages: languages, locale: .current, timeZone: .current)
        return Prompts.conflictChoice(answer: prompter.ask(prompt), remaining: conflict.remaining)
    }

    // MARK: Trash and delete

    /// Asks first; items the Trash refuses (a network share) can then be deleted permanently.
    func trash(_ urls: [URL]) async {
        guard !urls.isEmpty, prompter.ask(Prompts.trash(names: urls.map(\.lastPathComponent), languages: languages)) == 0 else { return }
        let outcome = await run(.delete, style: deletingStyle(urls)) { engine, control, progress in
            engine.trash(urls, control: control, progress: progress)
        }
        guard case .cannotTrash(let refused) = outcome.failure,
              prompter.ask(Prompts.cannotTrash(names: refused.map(\.lastPathComponent), languages: languages)) == 0 else { return }
        await removePermanently(refused)
    }

    func deletePermanently(_ urls: [URL]) async {
        guard !urls.isEmpty,
              prompter.ask(Prompts.deletePermanently(names: urls.map(\.lastPathComponent), languages: languages)) == 0 else { return }
        await removePermanently(urls)
    }

    /// Deletes everything in the Recycle Bin folder; undo history pointing into it is dropped.
    func emptyTrash(count: Int) async {
        guard prompter.ask(Prompts.emptyTrash(count: count, languages: languages)) == 0 else { return }
        let items = (try? FileManager.default.contentsOfDirectory(at: environment.trash, includingPropertiesForKeys: nil)) ?? []
        await removePermanently(items)
        undoStack.removeAll()
    }

    func restore(_ urls: [URL]) async -> [URL] {
        let changes = urls.compactMap { url in trashOrigins.origin(of: url).map { FileChange.trashed(original: $0, trashed: url) } }
        guard !changes.isEmpty else { return [] }
        let reversed = Array(changes.reversed())   // revert walks backwards: keep the selection's order
        return await run(.restore, style: movingStyle) { engine, control, progress in
            engine.revert(reversed, control: control, progress: progress)
        }.results
    }

    func canRestore(_ url: URL) -> Bool { trashOrigins.origin(of: url) != nil }

    private func removePermanently(_ urls: [URL]) async {
        _ = await run(.delete, records: false, style: deletingStyle(urls)) { engine, control, progress in
            engine.deletePermanently(urls, control: control, progress: progress)
        }
    }

    // MARK: New folder and rename

    func newFolder(in folder: URL) async -> URL? {
        let languages = self.languages
        return await run(.newFolder, style: movingStyle) { engine, _, _ in
            engine.newFolder(in: folder, languages: languages)
        }.results.first
    }

    /// Checks the name, asks when the extension changes or the name hides the item, then renames.
    /// Apps are edited without ".app", which is put back. nil = unchanged or refused.
    func rename(_ entry: FileEntry, to typed: String) async -> URL? {
        let isApp = entry.kind == .application
        let original = isApp ? (entry.url.lastPathComponent as NSString).deletingPathExtension : entry.url.lastPathComponent
        let name: String
        switch RenameRules.check(original: original, typed: typed, isFolder: entry.kind == .folder || isApp, languages: languages) {
        case .unchanged:
            return nil
        case .invalid(let message):
            _ = prompter.ask(Prompts.invalidName(message, languages: languages))
            return nil
        case .accept(let accepted):
            name = accepted
        case .confirmHidden(let hidden):
            guard prompter.ask(Prompts.hiddenName(languages: languages)) == 0 else { return nil }
            name = hidden
        case .confirmExtensionChange(let from, let to):
            guard prompter.ask(Prompts.extensionChange(from: from, to: to, languages: languages)) == 0 else { return nil }
            name = typed.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        let item = entry.url, target = isApp ? name + ".app" : name
        return await run(.rename, style: movingStyle) { engine, _, _ in engine.rename(item, to: target) }.results.first
    }

    // MARK: Undo

    func undo() async { await step(redo: false) }
    func redo() async { await step(redo: true) }

    private func step(redo: Bool) async {
        guard let name = redo ? undoStack.redoName : undoStack.undoName else { return }
        let revert: @MainActor ([FileChange]) async -> OperationOutcome = { [weak self] changes in
            guard let self else { return OperationOutcome() }
            return await self.run(name, records: false, isUndo: true, style: self.movingStyle) { engine, control, progress in
                engine.revert(changes, control: control, progress: progress)
            }
        }
        _ = redo ? await undoStack.redo(revert) : await undoStack.undo(revert)
    }

    // MARK: Running

    var runningOperations: Int { running.count }

    func cancelRunning() {
        running.values.forEach { $0.cancel() }
    }

    /// Returns once nothing is running (a cancelled copy has removed what it had written by then).
    func waitForOperations() async {
        guard !running.isEmpty else { return }
        await withCheckedContinuation { idleWaiters.append($0) }
    }

    /// Runs `work` on a background queue with a progress dialog after `progressDelay`, then records
    /// undo (unless told not to), remembers where trashed items came from, and reports a failure.
    private func run(_ action: FileActionName, records: Bool = true, isUndo: Bool = false, style: ProgressStyle,
                     _ work: @escaping @Sendable (FileOperations, OperationControl,
                                                  @escaping @Sendable (OperationProgress) -> Void) -> OperationOutcome) async -> OperationOutcome {
        let control = OperationControl()
        let presenter = ProgressPresenter(style: style, languages: languages, delay: progressDelay, control: control, owner: self)
        let engine = self.engine, box = presenter.box
        running[ObjectIdentifier(control)] = control
        undoStack.beginWork()
        presenter.start()
        let outcome = await withCheckedContinuation { (continuation: CheckedContinuation<OperationOutcome, Never>) in
            DispatchQueue.global(qos: .userInitiated).async {
                continuation.resume(returning: work(engine, control) { box.latest = $0 })
            }
        }
        presenter.finish()
        running[ObjectIdentifier(control)] = nil
        if running.isEmpty {
            idleWaiters.forEach { $0.resume() }
            idleWaiters = []
        }
        undoStack.endWork()
        if records && !isUndo { undoStack.record(FileAction(name: action, changes: outcome.changes)) }
        trashOrigins.record(outcome.changes)
        if let failure = outcome.failure { report(failure, action: action, isUndo: isUndo) }
        postChange()
        return outcome
    }

    /// Taking something out of the Trash fails without Full Disk Access: say how to do it instead.
    private func report(_ failure: OperationFailure, action: FileActionName, isUndo: Bool) {
        guard var prompt = Prompts.failure(failure, action: action, isUndo: isUndo, languages: languages) else { return }
        if isUndo || action == .restore, case .failed(let item, _) = failure, isInATrash(item) {
            prompt = prompt.appending(ExplorerText.trashAccessHint(languages))
        }
        _ = prompter.ask(prompt)
    }

    private func isInATrash(_ url: URL) -> Bool {
        url.standardizedFileURL.path.hasPrefix(environment.trash.standardizedFileURL.path + "/")
            || url.standardizedFileURL.pathComponents.contains(".Trashes")
    }

    private func postChange() {
        NotificationCenter.default.post(name: Self.didChange, object: self)
    }

    fileprivate func noteDialog(shown: Bool) {
        if shown { progressDialogsShown += 1 }
        visibleProgressDialogs += shown ? 1 : -1
    }

    private var movingStyle: ProgressStyle {
        ProgressStyle(title: ExplorerText.moving(languages), animation: .folderToFolder, detail: "")
    }

    private func deletingStyle(_ urls: [URL]) -> ProgressStyle {
        ProgressStyle(title: ExplorerText.deleting(languages), animation: .folderToBin,
                      detail: urls.first.map { ExplorerText.from(Self.displayName($0.deletingLastPathComponent()), languages) } ?? "")
    }

    private static func displayName(_ url: URL) -> String { FileManager.default.displayName(atPath: url.path) }

    private static func summary(of url: URL) -> (size: Int64?, modified: Date?) {
        let values = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey, .isDirectoryKey])
        return (values?.isDirectory == true ? nil : values?.fileSize.map(Int64.init), values?.contentModificationDate)
    }
}

private struct ProgressStyle {
    let title: String
    let animation: FileOperationAnimation.Style
    let detail: String
}

/// The latest progress, written by the engine's thread and read by the dialog's timer.
private final class ProgressBox: @unchecked Sendable {
    private let lock = NSLock()
    private var value: OperationProgress?

    var latest: OperationProgress? {
        get { lock.withLock { value } }
        set { lock.withLock { value = newValue } }
    }
}

/// Shows the progress dialog once an operation has run for `delay`, and refreshes it every 100 ms.
@MainActor
private final class ProgressPresenter {
    static let interval: TimeInterval = 0.1

    let box = ProgressBox()
    private let style: ProgressStyle
    private let languages: [String]
    private let delay: TimeInterval
    private let control: OperationControl
    private weak var owner: ExplorerOperations?
    private let started = Date()
    private var timer: Timer?
    private var dialog: RetroProgressDialog?

    init(style: ProgressStyle, languages: [String], delay: TimeInterval, control: OperationControl, owner: ExplorerOperations) {
        self.style = style
        self.languages = languages
        self.delay = delay
        self.control = control
        self.owner = owner
    }

    func start() {
        if delay <= 0 { show() }
        let timer = Timer(timeInterval: Self.interval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func finish() {
        timer?.invalidate()
        timer = nil
        guard let dialog else { return }
        dialog.close()
        self.dialog = nil
        owner?.noteDialog(shown: false)
    }

    private func tick() {
        if dialog == nil && Date().timeIntervalSince(started) >= delay { show() }
        update()
    }

    private func show() {
        let dialog = RetroProgressDialog(title: style.title, style: style.animation, cancelTitle: ExplorerText.cancel(languages))
        let control = self.control
        dialog.onCancel = { control.cancel() }
        self.dialog = dialog
        update()
        dialog.show()
        owner?.noteDialog(shown: true)
    }

    private func update() {
        guard let dialog else { return }
        let progress = box.latest, elapsed = Date().timeIntervalSince(started)
        let fraction = progress.map { $0.total > 0 ? Double($0.completed) / Double($0.total) : 0 } ?? 0
        let remaining = progress.flatMap { ProgressEstimate.remaining(completed: $0.completed, total: $0.total, elapsed: elapsed) }
        dialog.update(item: progress?.item.lastPathComponent ?? "", detail: style.detail, fraction: fraction,
                      remaining: ProgressEstimate.text(remaining, languages: languages))
    }
}
