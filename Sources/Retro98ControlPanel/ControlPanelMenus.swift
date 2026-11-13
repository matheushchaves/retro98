import AppKit

/// The macOS menu bar. Commands go up the responder chain: the window's delegate (the window controller)
/// takes Open and Back to normal, the window takes Close, Minimize and Zoom, the rest end at the app delegate.
@MainActor
enum ControlPanelMenus {
    static let helpURL = URL(string: "https://github.com/matheushchaves/retro98#readme")!

    private struct Command {
        let title: String
        var key = ""
        var modifiers: NSEvent.ModifierFlags = .command
        let selector: Selector
    }

    static func mainMenu(languages l: [String]) -> NSMenu {
        let main = NSMenu()
        main.addItem(submenu(ControlPanelText.appName, [
            Command(title: ControlPanelText.about(l), selector: #selector(AppDelegate.showAbout(_:))),
            nil,
            Command(title: ControlPanelText.settings(l), key: ",", selector: #selector(AppDelegate.showWindow(_:))),
            nil,
            Command(title: ControlPanelText.hide(l), key: "h", selector: #selector(NSApplication.hide(_:))),
            Command(title: ControlPanelText.hideOthers(l), key: "h", modifiers: [.command, .option],
                    selector: #selector(NSApplication.hideOtherApplications(_:))),
            Command(title: ControlPanelText.showAll(l), selector: #selector(NSApplication.unhideAllApplications(_:))),
            nil,
            Command(title: ControlPanelText.quit(l), key: "q", selector: #selector(NSApplication.terminate(_:))),
        ]))
        main.addItem(submenu(ControlPanelText.menuFile(l), [
            Command(title: ControlPanelText.open(l), key: "o", selector: #selector(ControlPanelWindowController.openSelected(_:))),
            nil,
            Command(title: ControlPanelText.backToNormal(l), selector: #selector(ControlPanelWindowController.backToNormal(_:))),
            nil,
            Command(title: ControlPanelText.close(l), key: "w", selector: #selector(NSWindow.performClose(_:))),
        ]))
        main.addItem(submenu(ControlPanelText.menuWindow(l), [
            Command(title: ControlPanelText.minimize(l), key: "m", selector: #selector(NSWindow.miniaturize(_:))),
            Command(title: ControlPanelText.zoom(l), selector: #selector(NSWindow.zoom(_:))),
            nil,
            Command(title: ControlPanelText.bringAllToFront(l), selector: #selector(NSApplication.arrangeInFront(_:))),
        ]))
        main.addItem(submenu(ControlPanelText.menuHelp(l), [
            Command(title: ControlPanelText.readme(l), selector: #selector(AppDelegate.openHelp(_:))),
            nil,
            Command(title: ControlPanelText.about(l), selector: #selector(AppDelegate.showAbout(_:))),
        ]))
        return main
    }

    /// AppKit lists open windows in the menu it is given as the Window menu.
    static func windowMenu(in main: NSMenu, languages: [String]) -> NSMenu? {
        main.items.first { $0.submenu?.title == ControlPanelText.menuWindow(languages) }?.submenu
    }

    private static func submenu(_ title: String, _ commands: [Command?]) -> NSMenuItem {
        let menu = NSMenu(title: title)
        for command in commands {
            guard let command else { menu.addItem(.separator()); continue }
            let item = menu.addItem(withTitle: command.title, action: command.selector, keyEquivalent: command.key)
            item.keyEquivalentModifierMask = command.modifiers
        }
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.submenu = menu
        return item
    }
}
