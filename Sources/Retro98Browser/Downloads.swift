import AppKit
import Retro98FilesCore
import Retro98UI

/// The transfer behind one download (a `WKDownload` when live).
@MainActor
protocol DownloadTransfer: AnyObject {
    var received: Int64 { get }
    /// nil when the server didn't say.
    var total: Int64? { get }
    /// Stops the transfer; `done` runs once nothing more will be written.
    func cancel(_ done: @escaping @MainActor @Sendable () -> Void)
}

/// The downloads in progress. Each is written as "<name>.download" and moved to a free name when done,
/// so nothing is ever replaced and no half file carries the final name.
@MainActor
final class DownloadCenter {
    /// Tests turn the progress dialogs off.
    var presentsDialogs = true
    /// A download arrived: the final file's name.
    var onFinish: ((String) -> Void)?

    private struct Active {
        let transfer: DownloadTransfer
        let file: DownloadFile
        let host: String
        let dialog: RetroProgressDialog?
    }

    let folder: URL
    private let prompter: BrowserPrompter
    private let languages: [String]
    private let locale: Locale
    private var active: [Active] = []

    init(folder: URL, prompter: BrowserPrompter, languages: [String], locale: Locale = .current) {
        self.folder = folder
        self.prompter = prompter
        self.languages = languages
        self.locale = locale
    }

    var activeCount: Int { active.count }

    /// Starts tracking and returns where the transfer must write (a file that doesn't exist yet).
    func begin(_ transfer: DownloadTransfer, suggestedName: String, host: String) -> URL {
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let inFlight = Set(active.map(\.file.partURL.lastPathComponent))
        let file = DownloadFile(suggestedName: suggestedName, folder: folder, inFlight: inFlight)
        var dialog: RetroProgressDialog?
        if presentsDialogs {
            let made = RetroProgressDialog(title: BrowserText.downloadTitle(languages), style: .folderToFolder,
                                           cancelTitle: BrowserText.cancel(languages))
            made.onCancel = { [weak self, weak transfer] in
                if let transfer { self?.cancel(transfer) }
            }
            dialog = made
        }
        active.append(Active(transfer: transfer, file: file, host: BrowserText.oneLine(host, limit: 80), dialog: dialog))
        progressed(transfer)
        dialog?.show()
        return file.partURL
    }

    func progressed(_ transfer: DownloadTransfer) {
        guard let entry = entry(for: transfer), let lines = lines(for: transfer) else { return }
        entry.dialog?.update(item: lines.item, detail: lines.detail, fraction: lines.fraction, remaining: BrowserText.toDownloads(languages))
    }

    func finished(_ transfer: DownloadTransfer) {
        guard let entry = remove(transfer) else { return }
        do {
            onFinish?(try entry.file.finish().lastPathComponent)
        } catch {
            // The file is complete: it stays under its ".download" name instead of being thrown away.
            let part = entry.file.partURL
            guard FileManager.default.fileExists(atPath: part.path) else {
                tellFailure(entry, message: error.localizedDescription)
                return
            }
            prompter.tell(BrowserText.downloadKeptAsPart(name: entry.file.name, part: part.lastPathComponent, languages),
                          icon: .warning, languages: languages)
        }
    }

    func failed(_ transfer: DownloadTransfer, message: String) {
        guard let entry = remove(transfer) else { return }
        entry.file.discard()
        tellFailure(entry, message: message)
    }

    /// The dialog's Cancel: the half file goes away, now and again once the transfer has really stopped.
    func cancel(_ transfer: DownloadTransfer) {
        guard let entry = remove(transfer) else { return }
        let file = entry.file
        file.discard()
        transfer.cancel { file.discard() }
    }

    /// Quitting.
    func cancelAll() {
        for entry in active { cancel(entry.transfer) }
    }

    /// The dialog lines for a transfer.
    func lines(for transfer: DownloadTransfer) -> (item: String, detail: String, fraction: Double)? {
        guard let entry = entry(for: transfer) else { return nil }
        let received = StatusText.bytes(max(transfer.received, 0), locale: locale)
        let item = BrowserText.saving(name: entry.file.name, host: entry.host, languages)
        guard let total = transfer.total, total > 0 else { return (item, received, 0) }
        let detail = BrowserText.receivedOfTotal(received, StatusText.bytes(total, locale: locale), languages)
        return (item, detail, min(max(Double(transfer.received) / Double(total), 0), 1))
    }

    private func entry(for transfer: DownloadTransfer) -> Active? {
        active.first { $0.transfer === transfer }
    }

    private func remove(_ transfer: DownloadTransfer) -> Active? {
        guard let index = active.firstIndex(where: { $0.transfer === transfer }) else { return nil }
        let entry = active.remove(at: index)
        entry.dialog?.close()
        return entry
    }

    private func tellFailure(_ entry: Active, message: String) {
        prompter.tell(BrowserText.downloadFailed(name: entry.file.name, message: BrowserText.oneLine(message), languages),
                      icon: .error, languages: languages)
    }
}
