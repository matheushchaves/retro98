import AppKit

/// What the Explorer asks of macOS beyond files: ejecting disks and opening files with a chosen app.
/// Tests pass closures that never touch real disks or apps.
struct ExplorerServices: Sendable {
    let eject: @Sendable (URL) throws -> Void
    /// The default app for a file and every app that can open it.
    let applications: @Sendable (URL) -> (default: URL?, all: [URL])
    let open: @Sendable ([URL], URL) -> Void

    static let live = ExplorerServices(
        eject: { try NSWorkspace.shared.unmountAndEjectDevice(at: $0) },
        applications: { url in (NSWorkspace.shared.urlForApplication(toOpen: url), NSWorkspace.shared.urlsForApplications(toOpen: url)) },
        open: { urls, app in NSWorkspace.shared.open(urls, withApplicationAt: app, configuration: NSWorkspace.OpenConfiguration()) }
    )
}
