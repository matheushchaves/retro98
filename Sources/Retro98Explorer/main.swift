import AppKit

let application = NSApplication.shared
let appDelegate = AppDelegate()
application.delegate = appDelegate
application.setActivationPolicy(.regular)
let mainMenu = ExplorerMenus.mainMenu(languages: Locale.preferredLanguages)
application.mainMenu = mainMenu
application.windowsMenu = ExplorerMenus.windowMenu(in: mainMenu, languages: Locale.preferredLanguages)
application.run()
