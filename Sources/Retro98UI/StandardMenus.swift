import AppKit

/// A hidden main menu so standard shortcuts (⌘X/⌘C/⌘V/⌘A/⌘Z, ⌘Q) work in retro apps' text fields;
/// AppKit only routes these key equivalents through the main menu.
@MainActor
public enum StandardMenus {
    public static func mainMenu(appName: String, languages: [String]) -> NSMenu {
        let isPortuguese = languages.first?.hasPrefix("pt") == true
        let main = NSMenu()

        let appMenu = NSMenu(title: appName)
        appMenu.addItem(withTitle: (isPortuguese ? "Encerrar " : "Quit ") + appName,
                        action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        main.addItem(submenuItem(appMenu))

        let edit = NSMenu(title: isPortuguese ? "Editar" : "Edit")
        edit.addItem(withTitle: isPortuguese ? "Desfazer" : "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        let redo = edit.addItem(withTitle: isPortuguese ? "Refazer" : "Redo", action: Selector(("redo:")), keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        edit.addItem(.separator())
        edit.addItem(withTitle: isPortuguese ? "Recortar" : "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: isPortuguese ? "Copiar" : "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: isPortuguese ? "Colar" : "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: isPortuguese ? "Selecionar Tudo" : "Select All",
                     action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        main.addItem(submenuItem(edit))
        return main
    }

    private static func submenuItem(_ menu: NSMenu) -> NSMenuItem {
        let item = NSMenuItem(title: menu.title, action: nil, keyEquivalent: "")
        item.submenu = menu
        return item
    }
}
