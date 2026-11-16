import AppKit
import Retro98UI

/// The same commands in the macOS menu bar (with shortcuts) and in the window's retro menu bar. Every command
/// goes up the responder chain: the page or the address field takes the editing ones, the window's controller
/// takes the ones about its tabs and its page, and the rest end at the app delegate.
@MainActor
enum BrowserMenus {
    static let helpURL = URL(string: "https://github.com/matheushchaves/retro98#readme")!
    static let tabNumbers = 1...9

    struct Command {
        let title: String
        let key: String
        let modifiers: NSEvent.ModifierFlags
        let selector: Selector

        init(_ title: String, _ key: String, _ modifiers: NSEvent.ModifierFlags, _ selector: Selector) {
            self.title = title
            self.key = key
            self.modifiers = modifiers
            self.selector = selector
        }

        /// A ⌘ shortcut.
        init(_ title: String, _ key: String, _ selector: Selector) {
            self.init(title, key, .command, selector)
        }

        /// No shortcut.
        init(_ title: String, _ selector: Selector) {
            self.init(title, "", [], selector)
        }
    }

    /// File, Edit, View, Go, Favorites and Help, shared by both menu bars (the favorites themselves come after).
    static func groups(_ l: [String]) -> [(title: String, commands: [Command?])] {
        typealias Window = BrowserWindowController
        return [
            (BrowserText.menuFile(l), [
                Command(BrowserText.newWindow(l), "n", #selector(AppDelegate.newWindow(_:))),
                Command(BrowserText.newTab(l), "t", #selector(Window.newTab(_:))),
                Command(BrowserText.openAddress(l), "l", #selector(Window.focusAddress(_:))),
                Command(BrowserText.openFile(l), "o", #selector(Window.openFile(_:))),
                nil,
                Command(BrowserText.openDownloads(l), "l", [.command, .option], #selector(AppDelegate.openDownloadsFolder(_:))),
                nil,
                Command(BrowserText.closeTab(l), "w", #selector(Window.closeTab(_:) as (Window) -> (Any?) -> Void)),
                Command(BrowserText.closeWindow(l), "w", [.command, .shift], #selector(AppDelegate.closeWindow(_:))),
            ]),
            (BrowserText.menuEdit(l), [
                Command(BrowserText.undo(l), "z", Selector(("undo:"))),
                Command(BrowserText.redo(l), "z", [.command, .shift], Selector(("redo:"))),
                nil,
                Command(BrowserText.cut(l), "x", #selector(NSText.cut(_:))),
                Command(BrowserText.copy(l), "c", #selector(NSText.copy(_:))),
                Command(BrowserText.paste(l), "v", #selector(NSText.paste(_:))),
                Command(BrowserText.selectAll(l), "a", #selector(NSResponder.selectAll(_:))),
                nil,
                Command(BrowserText.findInPage(l), "f", #selector(AppDelegate.showFind(_:))),
                Command(BrowserText.findNext(l), "g", #selector(AppDelegate.findNext(_:))),
            ]),
            (BrowserText.menuView(l), [
                Command(BrowserText.stop(l), ".", #selector(Window.stopPage(_:))),
                Command(BrowserText.refresh(l), "r", #selector(Window.reloadPage(_:))),
                nil,
                Command(BrowserText.zoomIn(l), "+", #selector(Window.zoomPageIn(_:))),
                Command(BrowserText.zoomOut(l), "-", #selector(Window.zoomPageOut(_:))),
                Command(BrowserText.zoomReset(l), "0", #selector(Window.zoomPageReset(_:))),
            ]),
            (BrowserText.menuGo(l), [
                Command(BrowserText.back(l), "[", #selector(Window.pageBack(_:))),
                Command(BrowserText.forward(l), "]", #selector(Window.pageForward(_:))),
                Command(BrowserText.home(l), "h", [.command, .shift], #selector(Window.goHome(_:))),
                nil,
                Command(BrowserText.nextTab(l), "\t", [.control], #selector(Window.showNextTab(_:))),
                Command(BrowserText.previousTab(l), "\t", [.control, .shift], #selector(Window.showPreviousTab(_:))),
                nil,
                Command(BrowserText.historyItem(l), "y", #selector(AppDelegate.showHistory(_:))),
                Command(BrowserText.clearData(l), #selector(AppDelegate.clearBrowsingData(_:))),
                nil,
                Command(BrowserText.useCurrentAsHome(l), #selector(Window.useCurrentPageAsHome(_:))),
                Command(BrowserText.useDefaultHome(l), #selector(Window.useDefaultHome(_:))),
            ]),
            (BrowserText.favorites(l), [
                Command(BrowserText.addFavorite(l), "d", #selector(Window.addFavorite(_:))),
                Command(BrowserText.organizeFavorites(l), #selector(AppDelegate.organizeFavorites(_:))),
                nil,
            ]),
            (BrowserText.menuHelp(l), [
                Command(BrowserText.readme(l), #selector(AppDelegate.openHelp(_:))),
                nil,
                Command(BrowserText.about(l), #selector(AppDelegate.showAbout(_:))),
            ]),
        ]
    }

    /// The macOS menu bar: the app menu, the shared menus, the standard Window menu, then Help.
    static func mainMenu(languages l: [String]) -> NSMenu {
        let main = NSMenu()
        main.addItem(submenu(menu(title: BrowserText.appName, [
            Command(BrowserText.about(l), #selector(AppDelegate.showAbout(_:))),
            nil,
            Command(BrowserText.hide(l), "h", #selector(NSApplication.hide(_:))),
            Command(BrowserText.hideOthers(l), "h", [.command, .option], #selector(NSApplication.hideOtherApplications(_:))),
            Command(BrowserText.showAll(l), #selector(NSApplication.unhideAllApplications(_:))),
            nil,
            Command(BrowserText.quit(l), "q", #selector(NSApplication.terminate(_:))),
        ])))
        let shared = groups(l)
        for group in shared.dropLast() { main.addItem(submenu(menu(title: group.title, group.commands))) }
        let window = menu(title: BrowserText.menuWindow(l), [
            Command(BrowserText.minimize(l), "m", #selector(NSWindow.miniaturize(_:))),
            Command(BrowserText.zoomWindow(l), #selector(NSWindow.zoom(_:))),
            nil,
            Command(BrowserText.bringAllToFront(l), #selector(NSApplication.arrangeInFront(_:))),
        ])
        addHiddenShortcuts(to: window, languages: l)
        main.addItem(submenu(window))
        if let help = shared.last { main.addItem(submenu(menu(title: help.title, help.commands))) }
        return main
    }

    /// Shortcuts with no line in the menus: ⌘1…⌘9 for the tabs, and the second spellings of next tab,
    /// previous tab and zoom in (⌘⇧], ⌘⇧[, ⌘=).
    private static func addHiddenShortcuts(to menu: NSMenu, languages l: [String]) {
        typealias Window = BrowserWindowController
        var hidden: [NSMenuItem] = tabNumbers.map { number in
            let item = NSMenuItem(title: BrowserText.tabNumber(number, l), action: #selector(Window.selectTabByNumber(_:)),
                                  keyEquivalent: String(number))
            item.tag = number
            return item
        }
        hidden.append(NSMenuItem(title: BrowserText.nextTab(l), action: #selector(Window.showNextTab(_:)), keyEquivalent: "}"))
        hidden.append(NSMenuItem(title: BrowserText.previousTab(l), action: #selector(Window.showPreviousTab(_:)), keyEquivalent: "{"))
        hidden.append(NSMenuItem(title: BrowserText.zoomIn(l), action: #selector(Window.zoomPageIn(_:)), keyEquivalent: "="))
        for item in hidden {
            item.keyEquivalentModifierMask = .command
            item.isHidden = true
            item.allowsKeyEquivalentWhenHidden = true
            menu.addItem(item)
        }
    }

    /// AppKit lists open windows in the menu it is given as the Window menu.
    static func windowMenu(in main: NSMenu, languages: [String]) -> NSMenu? {
        main.items.first { $0.submenu?.title == BrowserText.menuWindow(languages) }?.submenu
    }

    /// The Favorites menu, which the app delegate fills with the favorites each time it opens.
    static func favoritesMenu(in main: NSMenu, languages: [String]) -> NSMenu? {
        main.items.first { $0.submenu?.title == BrowserText.favorites(languages) }?.submenu
    }

    /// The window's retro menu bar: the same commands, sent up the responder chain. `favorites` gives the whole
    /// Favorites menu (its two commands and the list), which belongs to the window.
    static func retroMenus(languages: [String], favorites: @escaping @Sendable @MainActor () -> [RetroMenuItem]) -> [RetroMenuBarMenu] {
        let favoritesTitle = BrowserText.favorites(languages)
        return groups(languages).map { group in
            if group.title == favoritesTitle { return RetroMenuBarMenu(title: group.title, items: favorites) }
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
