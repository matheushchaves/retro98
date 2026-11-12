import AppKit
import Retro98UI

/// The same commands in the macOS menu bar (with shortcuts) and in the window's retro menu bar. Every command
/// goes up the responder chain: the terminal takes Copy, Paste and Select All, the window controller's
/// window takes Minimize and Zoom, and the rest end at the app delegate. ⌘ shortcuts reach the menus first;
/// Control and Option keys go to the terminal.
@MainActor
enum PromptMenus {
    static let helpURL = URL(string: "https://github.com/matheushchaves/retro98#readme")!

    struct Command {
        let title: String
        let key: String
        let modifiers: NSEvent.ModifierFlags
        let selector: Selector
    }

    /// File, Edit and Help, shared by both menu bars.
    static func groups(_ l: [String]) -> [(title: String, commands: [Command?])] {
        [
            (PromptText.menuFile(l), [
                Command(title: PromptText.newWindow(l), key: "n", modifiers: .command, selector: #selector(AppDelegate.newWindow(_:))),
                nil,
                Command(title: PromptText.close(l), key: "w", modifiers: .command, selector: #selector(AppDelegate.closeWindow(_:))),
            ]),
            (PromptText.menuEdit(l), [
                Command(title: PromptText.copy(l), key: "c", modifiers: .command, selector: #selector(NSText.copy(_:))),
                Command(title: PromptText.paste(l), key: "v", modifiers: .command, selector: #selector(NSText.paste(_:))),
                nil,
                Command(title: PromptText.selectAll(l), key: "a", modifiers: .command, selector: #selector(NSResponder.selectAll(_:))),
            ]),
            (PromptText.menuHelp(l), [
                Command(title: PromptText.readme(l), key: "", modifiers: [], selector: #selector(AppDelegate.openHelp(_:))),
                nil,
                Command(title: PromptText.about(l), key: "", modifiers: [], selector: #selector(AppDelegate.showAbout(_:))),
            ]),
        ]
    }

    /// The macOS menu bar: the app menu, File and Edit, the standard Window menu, then Help.
    static func mainMenu(languages l: [String]) -> NSMenu {
        let main = NSMenu()
        main.addItem(submenu(menu(title: PromptText.appName, [
            Command(title: PromptText.about(l), key: "", modifiers: [], selector: #selector(AppDelegate.showAbout(_:))),
            nil,
            Command(title: PromptText.hide(l), key: "h", modifiers: .command, selector: #selector(NSApplication.hide(_:))),
            Command(title: PromptText.hideOthers(l), key: "h", modifiers: [.command, .option],
                    selector: #selector(NSApplication.hideOtherApplications(_:))),
            Command(title: PromptText.showAll(l), key: "", modifiers: [], selector: #selector(NSApplication.unhideAllApplications(_:))),
            nil,
            Command(title: PromptText.quit(l), key: "q", modifiers: .command, selector: #selector(NSApplication.terminate(_:))),
        ])))
        let shared = groups(l)
        for group in shared.dropLast() { main.addItem(submenu(menu(title: group.title, group.commands))) }
        main.addItem(submenu(menu(title: PromptText.menuWindow(l), [
            Command(title: PromptText.minimize(l), key: "m", modifiers: .command, selector: #selector(NSWindow.miniaturize(_:))),
            Command(title: PromptText.zoom(l), key: "", modifiers: [], selector: #selector(NSWindow.zoom(_:))),
            nil,
            Command(title: PromptText.bringAllToFront(l), key: "", modifiers: [], selector: #selector(NSApplication.arrangeInFront(_:))),
        ])))
        if let help = shared.last { main.addItem(submenu(menu(title: help.title, help.commands))) }
        return main
    }

    /// AppKit lists open windows in the menu it is given as the Window menu.
    static func windowMenu(in main: NSMenu, languages: [String]) -> NSMenu? {
        main.items.first { $0.submenu?.title == PromptText.menuWindow(languages) }?.submenu
    }

    /// The window's retro menu bar: the same commands, sent up the responder chain.
    static func retroMenus(languages: [String]) -> [RetroMenuBarMenu] {
        groups(languages).map { group in
            let commands = group.commands
            return RetroMenuBarMenu(title: group.title) {
                commands.map { command in
                    guard let command else { return .separator }
                    let selector = command.selector
                    let application = NSApplication.shared
                    return RetroMenuItem(title: command.title, kind: .action({ application.sendAction(selector, to: nil, from: nil) }),
                                         isEnabled: application.target(forAction: selector, to: nil, from: nil) != nil)
                }
            }
        }
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

    private static func submenu(_ menu: NSMenu) -> NSMenuItem {
        let item = NSMenuItem(title: menu.title, action: nil, keyEquivalent: "")
        item.submenu = menu
        return item
    }
}
