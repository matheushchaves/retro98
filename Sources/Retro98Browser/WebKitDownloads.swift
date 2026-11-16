import Foundation
import WebKit

/// One `WKDownload` as the download center sees it. WebKit reports progress on its own threads; it is passed
/// on to the main actor a few times a second at most.
@MainActor
final class WebKitTransfer: DownloadTransfer {
    static let updateInterval: TimeInterval = 0.1

    let download: WKDownload
    private var observation: NSKeyValueObservation?
    private var lastUpdate = Date.distantPast

    init(download: WKDownload, onProgress: @escaping @MainActor (WebKitTransfer) -> Void) {
        self.download = download
        observation = download.progress.observe(\.fractionCompleted) { [weak self] _, _ in
            Task { @MainActor [weak self] in
                guard let self, Date().timeIntervalSince(lastUpdate) >= Self.updateInterval else { return }
                lastUpdate = Date()
                onProgress(self)
            }
        }
    }

    var received: Int64 { download.progress.completedUnitCount }

    var total: Int64? {
        let total = download.progress.totalUnitCount
        return total > 0 ? total : nil
    }

    func cancel(_ done: @escaping @MainActor @Sendable () -> Void) {
        stopObserving()
        download.cancel { _ in
            MainActor.assumeIsolated { done() }
        }
    }

    func stopObserving() {
        observation?.invalidate()
        observation = nil
    }
}

/// Connects WebKit's downloads to the download center.
@MainActor
final class WebKitDownloads: NSObject, WKDownloadDelegate {
    private let center: DownloadCenter
    /// Downloads in progress, kept alive here.
    private var transfers: [WebKitTransfer] = []

    init(center: DownloadCenter) {
        self.center = center
    }

    /// Takes over a download a page started.
    func adopt(_ download: WKDownload) {
        download.delegate = self
        transfers.append(WebKitTransfer(download: download) { [weak self] in self?.center.progressed($0) })
    }

    private func transfer(for download: WKDownload) -> WebKitTransfer? {
        transfers.first { $0.download === download }
    }

    private func release(_ download: WKDownload) -> WebKitTransfer? {
        guard let transfer = transfer(for: download) else { return nil }
        transfer.stopObserving()
        transfers.removeAll { $0 === transfer }
        return transfer
    }

    func download(_ download: WKDownload, decideDestinationUsing response: URLResponse, suggestedFilename: String) async -> URL? {
        guard let transfer = transfer(for: download) else { return nil }
        return center.begin(transfer, suggestedName: suggestedFilename, host: response.url?.host() ?? "")
    }

    func downloadDidFinish(_ download: WKDownload) {
        if let transfer = release(download) { center.finished(transfer) }
    }

    /// A download the person cancelled is no longer in the center, so this says nothing about it.
    func download(_ download: WKDownload, didFailWithError error: any Error, resumeData: Data?) {
        if let transfer = release(download) { center.failed(transfer, message: error.localizedDescription) }
    }
}
