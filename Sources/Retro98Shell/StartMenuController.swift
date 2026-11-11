import AppKit
import Retro98ShellCore
import Retro98UI

/// Builds and shows the Start menu; turns menu choices into actions.
@MainActor
final class StartMenuController {
    private let languages: [String]
    private let documents: RecentDocumentsProvider
    private var programs: [ProgramNode]
    private var menu: RetroMenu?
    private var iconCache: [URL: PixelIcon] = [:]

    init(languages: [String], documents: RecentDocumentsProvider = SpotlightRecentDocuments()) {
        self.languages = languages
        self.documents = documents
        programs = ProgramsTreeBuilder.build(roots: Self.appRoots)
    }

    static var appRoots: [URL] { ProgramsTreeBuilder.standardRoots(FileManager.default.homeDirectoryForCurrentUser) }

    var isOpen: Bool { menu?.isOpen ?? false }

    /// `point` is the menu's bottom-left corner (top of the taskbar).
    func open(at point: CGPoint, ignoresClick: @escaping (NSEvent) -> Bool, onClose: @escaping () -> Void) {
        let nodes = StartMenuItems.build(
            programs: programs, documents: documents.recent(limit: StartMenuModel.recentDocumentsLimit), languages: languages
        )
        let menu = RetroMenu(items: nodes.map { item($0, large: true) }, style: .startMenu)
        menu.ignoresClick = ignoresClick
        menu.show(at: point, opensUpward: true) { [weak self] in
            self?.menu = nil
            onClose()
        }
        self.menu = menu
        refreshProgramsInBackground()
    }

    func close() { menu?.close() }

    /// Apps installed or removed since the last opening show up next time.
    private func refreshProgramsInBackground() {
        let roots = Self.appRoots
        Task.detached(priority: .utility) {
            let tree = ProgramsTreeBuilder.build(roots: roots)
            await MainActor.run { [weak self] in self?.programs = tree }
        }
    }

    private func item(_ node: StartMenuNode?, large: Bool) -> RetroMenuItem {
        guard let node else { return .separator }
        let icon = icon(for: node, large: large)
        if let children = node.children {
            return RetroMenuItem(title: node.title, icon: icon, kind: .submenu({ [weak self] in
                guard let self else { return [] }
                return children.map { self.item($0, large: false) }
            }))
        }
        guard let action = node.action else {
            return RetroMenuItem(title: node.title, icon: icon, kind: .action({}), isEnabled: false)
        }
        return RetroMenuItem(title: node.title, icon: icon, kind: .action({ [weak self] in self?.perform(action) }))
    }

    private func perform(_ action: StartMenuAction) {
        switch action {
        case .open(let url): NSWorkspace.shared.open(url)
        case .run: RunDialog.show(languages: languages)
        case .shutDown: ShutdownDialog.show(languages: languages)
        }
    }

    private func icon(for node: StartMenuNode, large: Bool) -> PixelIcon? {
        if let symbol = node.symbol { return builtIn(symbol, large: large) }
        guard let url = node.iconURL else { return nil }
        if let cached = iconCache[url] { return cached }
        let size = large ? 32 : 16
        let image = PixelIcon.appIcon(for: url, size: size)
        let icon = PixelIcon(width: size, height: size) { context in
            PixelIcon.drawUpright(image, in: CGRect(x: 0, y: 0, width: size, height: size), context: context)
        }
        iconCache[url] = icon
        return icon
    }

    private func builtIn(_ symbol: StartMenuSymbol, large: Bool) -> PixelIcon {
        switch symbol {
        case .programs: Icons.programs
        case .documents: Icons.documents
        case .settings: Icons.settings
        case .help: Icons.help
        case .run: Icons.run
        case .shutDown: Icons.shutDown
        case .folder: Icons.folder
        case .systemSettings: Icons.systemSettings
        }
    }
}
