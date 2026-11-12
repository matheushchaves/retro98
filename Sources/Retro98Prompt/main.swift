import AppKit

let application = NSApplication.shared
let appDelegate = AppDelegate()
application.delegate = appDelegate
application.setActivationPolicy(.regular)
let mainMenu = PromptMenus.mainMenu(languages: Locale.preferredLanguages)
application.mainMenu = mainMenu
application.windowsMenu = PromptMenus.windowMenu(in: mainMenu, languages: Locale.preferredLanguages)
application.run()
