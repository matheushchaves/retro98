import AppKit
import Retro98FilesCore
import Retro98UI

/// The same commands in the macOS menu bar (with shortcuts) and in the window's retro menu bar.
/// Every command goes up the responder chain: Cut/Copy/Paste only light up while the address
/// field is editing (file operations arrive in Phase 3B); the rest end at the app delegate.
@MainActor
enum ExplorerMenus {
    static let helpURL = URL(string: "https://github.com/matheushchaves/retro98#readme")!

    struct Command {
        let title: String
        let key: String
        let modifiers: NSEvent.ModifierFlags
        let selector: Selector
    }

    static func groups(_ l: [String]) -> [(title: String, commands: [Command?])] {
        let command = { (title: String, key: String, modifiers: NSEvent.ModifierFlags, selector: Selector) in
            Command(title: title, key: key, modifiers: modifiers, selector: selector)
        }
        return [
            (ExplorerText.menuFile(l), [
                command(ExplorerText.newWindow(l), "n", .command, #selector(AppDelegate.newWindow(_:))),
                command(ExplorerText.close(l), "w", .command, #selector(AppDelegate.closeWindow(_:))),
            ]),
            (ExplorerText.menuEdit(l), [
                command(ExplorerText.undo(l), "z", .command, Selector(("undo:"))),
                command(ExplorerText.redo(l), "z", [.command, .shift], Selector(("redo:"))), nil,
                command(ExplorerText.cut(l), "x", .command, #selector(NSText.cut(_:))),
                command(ExplorerText.copy(l), "c", .command, #selector(NSText.copy(_:))),
                command(ExplorerText.paste(l), "v", .command, #selector(NSText.paste(_:))), nil,
                command(ExplorerText.selectAll(l), "a", .command, #selector(NSResponder.selectAll(_:))),
            ]),
            (ExplorerText.menuView(l), [command(ExplorerText.refresh(l), "r", .command, #selector(AppDelegate.refresh(_:)))]),
            (ExplorerText.menuGo(l), [
                command(ExplorerText.back(l), "[", .command, #selector(AppDelegate.goBack(_:))),
                command(ExplorerText.forward(l), "]", .command, #selector(AppDelegate.goForward(_:))),
                command(ExplorerText.up(l), String(UnicodeScalar(NSUpArrowFunctionKey)!), .command, #selector(AppDelegate.goUp(_:))), nil,
                command(ExplorerText.desktop(l), "d", [.command, .shift], #selector(AppDelegate.goDesktop(_:))),
                command(ExplorerText.myComputer(l), "c", [.command, .shift], #selector(AppDelegate.goMyComputer(_:))),
                command(ExplorerText.myDocuments(l), "o", [.command, .shift], #selector(AppDelegate.goDocuments(_:))),
                command(ExplorerText.downloads(l), "l", [.command, .option], #selector(AppDelegate.goDownloads(_:))),
            ]),
            (ExplorerText.menuFavorites(l), [
                command(ExplorerText.desktop(l), "", [], #selector(AppDelegate.goDesktop(_:))),
                command(ExplorerText.myDocuments(l), "", [], #selector(AppDelegate.goDocuments(_:))),
                command(ExplorerText.downloads(l), "", [], #selector(AppDelegate.goDownloads(_:))),
                command(ExplorerText.applications(l), "", [], #selector(AppDelegate.goApplications(_:))),
            ]),
            (ExplorerText.menuHelp(l), [command(ExplorerText.readme(l), "", [], #selector(AppDelegate.openHelp(_:)))]),
        ]
    }

    /// The macOS menu bar: the app menu, the shared groups, and the standard Window menu before Help
    /// (the Mac shortcuts keep working in retro apps).
    static func mainMenu(languages l: [String]) -> NSMenu {
        let main = NSMenu()
        main.addItem(submenu(menu(title: "Retro98 Explorer", [
            Command(title: ExplorerText.about(l), key: "", modifiers: [], selector: #selector(NSApplication.orderFrontStandardAboutPanel(_:))),
            nil,
            Command(title: ExplorerText.hide(l), key: "h", modifiers: .command, selector: #selector(NSApplication.hide(_:))),
            Command(title: ExplorerText.hideOthers(l), key: "h", modifiers: [.command, .option],
                    selector: #selector(NSApplication.hideOtherApplications(_:))),
            Command(title: ExplorerText.showAll(l), key: "", modifiers: [], selector: #selector(NSApplication.unhideAllApplications(_:))),
            nil,
            Command(title: ExplorerText.quit(l), key: "q", modifiers: .command, selector: #selector(NSApplication.terminate(_:))),
        ])))
        let shared = groups(l)
        for group in shared.dropLast() { main.addItem(submenu(menu(title: group.title, group.commands))) }
        main.addItem(submenu(menu(title: ExplorerText.menuWindow(l), [
            Command(title: ExplorerText.minimize(l), key: "m", modifiers: .command, selector: #selector(NSWindow.miniaturize(_:))),
            Command(title: ExplorerText.zoom(l), key: "", modifiers: [], selector: #selector(NSWindow.zoom(_:))),
            nil,
            Command(title: ExplorerText.bringAllToFront(l), key: "", modifiers: [], selector: #selector(NSApplication.arrangeInFront(_:))),
        ])))
        if let help = shared.last { main.addItem(submenu(menu(title: help.title, help.commands))) }
        return main
    }

    /// AppKit lists open windows in the menu it is given as the Window menu.
    static func windowMenu(in main: NSMenu, languages: [String]) -> NSMenu? {
        main.items.first { $0.submenu?.title == ExplorerText.menuWindow(languages) }?.submenu
    }

    private static func menu(title: String, _ commands: [Command?]) -> NSMenu {
        let menu = NSMenu(title: title)
        for command in commands {
            guard let command else { menu.addItem(.separator()); continue }
            let item = menu.addItem(withTitle: command.title, action: command.selector, keyEquivalent: command.key)
            item.keyEquivalentModifierMask = command.modifiers
        }
        return menu
    }

    /// The window's retro menu bar: same commands, sent to the app delegate.
    static func retroMenus(languages: [String]) -> [RetroMenuBarMenu] {
        groups(languages).map { group in
            let commands = group.commands
            return RetroMenuBarMenu(title: group.title) {
                commands.map { command in
                    guard let command else { return .separator }
                    let selector = command.selector
                    return RetroMenuItem(title: command.title, kind: .action({ NSApp.sendAction(selector, to: nil, from: nil) }),
                                         isEnabled: NSApp.target(forAction: selector, to: nil, from: nil) != nil)
                }
            }
        }
    }

    private static func submenu(_ menu: NSMenu) -> NSMenuItem {
        let item = NSMenuItem(title: menu.title, action: nil, keyEquivalent: "")
        item.submenu = menu
        return item
    }
}
