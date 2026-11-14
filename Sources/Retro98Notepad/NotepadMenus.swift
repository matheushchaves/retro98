import AppKit
import Retro98UI

/// The same commands in the macOS menu bar (with shortcuts) and in the window's retro menu bar. Every command
/// goes up the responder chain: the text takes the editing ones, the window's controller takes Save and
/// Time/Date, the window takes Minimize and Zoom, and the rest end at the app delegate.
@MainActor
enum NotepadMenus {
    static let helpURL = URL(string: "https://github.com/matheushchaves/retro98#readme")!
    static let f5 = String(UnicodeScalar(NSF5FunctionKey)!)

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

    /// File, Edit, Search, Format and Help, shared by both menu bars.
    static func groups(_ l: [String]) -> [(title: String, commands: [Command?])] {
        let timeDate = #selector(NotepadWindowController.insertTimeDate(_:) as (NotepadWindowController) -> (Any?) -> Void)
        return [
            (NotepadText.menuFile(l), [
                Command(NotepadText.new(l), "n", #selector(AppDelegate.newDocument(_:))),
                Command(NotepadText.open(l), "o", #selector(AppDelegate.openDocument(_:))),
                Command(NotepadText.save(l), "s", #selector(NotepadWindowController.saveDocument(_:))),
                Command(NotepadText.saveAs(l), "s", [.command, .shift], #selector(NotepadWindowController.saveDocumentAs(_:))),
                nil,
                Command(NotepadText.close(l), "w", #selector(AppDelegate.closeWindow(_:))),
            ]),
            (NotepadText.menuEdit(l), [
                Command(NotepadText.undo(l), "z", Selector(("undo:"))),
                Command(NotepadText.redo(l), "z", [.command, .shift], Selector(("redo:"))),
                nil,
                Command(NotepadText.cut(l), "x", #selector(NSText.cut(_:))),
                Command(NotepadText.copy(l), "c", #selector(NSText.copy(_:))),
                Command(NotepadText.paste(l), "v", #selector(NSText.paste(_:))),
                Command(NotepadText.delete(l), #selector(NSText.delete(_:))),
                nil,
                Command(NotepadText.selectAll(l), "a", #selector(NSResponder.selectAll(_:))),
                Command(NotepadText.timeDateItem(l), f5, [], timeDate),
            ]),
            (NotepadText.menuSearch(l), [
                Command(NotepadText.find(l), "f", #selector(AppDelegate.showFind(_:))),
                Command(NotepadText.findNext(l), "g", #selector(AppDelegate.findNext(_:))),
            ]),
            (NotepadText.menuFormat(l), [
                Command(NotepadText.wordWrap(l), #selector(AppDelegate.toggleWordWrap(_:))),
            ]),
            (NotepadText.menuHelp(l), [
                Command(NotepadText.readme(l), #selector(AppDelegate.openHelp(_:))),
                nil,
                Command(NotepadText.about(l), #selector(AppDelegate.showAbout(_:))),
            ]),
        ]
    }

    /// The macOS menu bar: the app menu, the shared menus, the standard Window menu, then Help.
    static func mainMenu(languages l: [String]) -> NSMenu {
        let main = NSMenu()
        main.addItem(submenu(menu(title: NotepadText.appName, [
            Command(NotepadText.about(l), #selector(AppDelegate.showAbout(_:))),
            nil,
            Command(NotepadText.hide(l), "h", #selector(NSApplication.hide(_:))),
            Command(NotepadText.hideOthers(l), "h", [.command, .option], #selector(NSApplication.hideOtherApplications(_:))),
            Command(NotepadText.showAll(l), #selector(NSApplication.unhideAllApplications(_:))),
            nil,
            Command(NotepadText.quit(l), "q", #selector(NSApplication.terminate(_:))),
        ])))
        let shared = groups(l)
        for group in shared.dropLast() { main.addItem(submenu(menu(title: group.title, group.commands))) }
        main.addItem(submenu(menu(title: NotepadText.menuWindow(l), [
            Command(NotepadText.minimize(l), "m", #selector(NSWindow.miniaturize(_:))),
            Command(NotepadText.zoom(l), #selector(NSWindow.zoom(_:))),
            nil,
            Command(NotepadText.bringAllToFront(l), #selector(NSApplication.arrangeInFront(_:))),
        ])))
        if let help = shared.last { main.addItem(submenu(menu(title: help.title, help.commands))) }
        return main
    }

    /// AppKit lists open windows in the menu it is given as the Window menu.
    static func windowMenu(in main: NSMenu, languages: [String]) -> NSMenu? {
        main.items.first { $0.submenu?.title == NotepadText.menuWindow(languages) }?.submenu
    }

    /// The window's retro menu bar: the same commands, sent up the responder chain; Word Wrap shows a check.
    static func retroMenus(languages: [String], wordWrap: @escaping @Sendable @MainActor () -> Bool) -> [RetroMenuBarMenu] {
        groups(languages).map { group in
            let commands = group.commands
            return RetroMenuBarMenu(title: group.title) {
                commands.map { command in
                    guard let command else { return .separator }
                    let selector = command.selector
                    let application = NSApplication.shared
                    let isChecked = selector == #selector(AppDelegate.toggleWordWrap(_:)) && wordWrap()
                    return RetroMenuItem(title: command.title, kind: .action({ application.sendAction(selector, to: nil, from: nil) }),
                                         isEnabled: application.target(forAction: selector, to: nil, from: nil) != nil,
                                         mark: isChecked ? .check : .none)
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
