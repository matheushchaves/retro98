import AppKit
import Retro98FilesCore
import Retro98UI

/// "Open With" (the default app first, then the others, then "Other…") and ejecting disks.
extension ExplorerWindowController {
    @objc func openWith(_ sender: Any?) {
        guard isEnabled(#selector(openWith(_:))) else { return }
        let menu = RetroMenu(items: openWithItems(for: selectedEntries.map(\.url)), style: .standard)
        contextMenu = menu
        menu.show(at: NSEvent.mouseLocation, opensUpward: false) {}
    }

    /// The apps that open the first item; the chosen one opens all of them.
    func openWithItems(for urls: [URL]) -> [RetroMenuItem] {
        guard let first = urls.first else { return [] }
        let services = operations.services
        let apps = services.applications(first)
        let choices = OpenWithList.choices(defaultApp: apps.default, apps: apps.all)
        let items = choices.map { choice in
            let app = choice.app
            return RetroMenuItem(title: choice.isDefault ? ExplorerText.defaultApp(choice.name, languages) : choice.name,
                                 icon: Self.appIcon(app), kind: .action({ services.open(urls, app) }))
        }
        let other = RetroMenuItem(title: ExplorerText.otherApp(languages), kind: .action({ [weak self] in self?.chooseOtherApp(for: urls) }))
        return items + [.separator, other]
    }

    private func chooseOtherApp(for urls: [URL]) {
        let panel = NSOpenPanel()
        panel.directoryURL = URL(filePath: "/Applications")
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let app = panel.url else { return }
        operations.services.open(urls, app)
    }

    private static func appIcon(_ app: URL) -> PixelIcon {
        let image = PixelIcon.appIcon(for: app, size: 16)
        return PixelIcon(width: 16, height: 16) { PixelIcon.drawUpright(image, in: CGRect(x: 0, y: 0, width: 16, height: 16), context: $0) }
    }

    /// Ejects the selected disks off the main thread; a disk in use says why.
    @objc func ejectSelection(_ sender: Any?) {
        guard isEnabled(#selector(ejectSelection(_:))) else { return }
        let disks = selectedEntries.map { (url: $0.url, name: $0.name) }
        let services = operations.services
        spawn { [weak self] in
            for disk in disks {
                let failure: String? = await withCheckedContinuation { continuation in
                    DispatchQueue.global(qos: .userInitiated).async {
                        do {
                            try services.eject(disk.url)
                            continuation.resume(returning: nil)
                        } catch {
                            continuation.resume(returning: error.localizedDescription)
                        }
                    }
                }
                guard let self, let failure else { continue }
                _ = self.operations.ask(Prompts.ejectFailed(name: disk.name, reason: failure, languages: self.languages))
            }
        }
    }
}
