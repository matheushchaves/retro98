import AppKit
import Retro98UI

let application = NSApplication.shared
let appDelegate = AppDelegate()
application.delegate = appDelegate
application.setActivationPolicy(.accessory)
// Hidden main menu: gives text fields ⌘X/⌘C/⌘V/⌘A/⌘Z.
application.mainMenu = StandardMenus.mainMenu(appName: "Retro98 Shell", languages: Locale.preferredLanguages)
application.run()
