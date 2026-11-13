import AppKit
import Retro98Settings
import Retro98UI

// Retro98's sounds follow the Control Panel's switch, read each time one plays.
RetroSound.isEnabled = { ChoicesFile.live().load().soundsOn }
let application = NSApplication.shared
let appDelegate = AppDelegate()
application.delegate = appDelegate
application.setActivationPolicy(.accessory)
// Hidden main menu: gives text fields ⌘X/⌘C/⌘V/⌘A/⌘Z.
application.mainMenu = StandardMenus.mainMenu(appName: "Retro98 Shell", languages: Locale.preferredLanguages)
application.run()
