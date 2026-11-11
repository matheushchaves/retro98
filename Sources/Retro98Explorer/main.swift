import AppKit

let application = NSApplication.shared
let appDelegate = AppDelegate()
application.delegate = appDelegate
application.setActivationPolicy(.regular)
application.mainMenu = ExplorerMenus.mainMenu(languages: Locale.preferredLanguages)
application.run()
