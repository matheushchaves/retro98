import AppKit
import Retro98Settings
import Retro98UI

// Retro98's sounds follow the Control Panel's switch, read each time one plays.
RetroSound.isEnabled = { ChoicesFile.live().load().soundsOn }
let application = NSApplication.shared
let appDelegate = AppDelegate.live()
application.delegate = appDelegate
application.setActivationPolicy(.regular)
let mainMenu = BrowserMenus.mainMenu(languages: Locale.preferredLanguages)
application.mainMenu = mainMenu
application.windowsMenu = BrowserMenus.windowMenu(in: mainMenu, languages: Locale.preferredLanguages)
let favoritesMenu = BrowserMenus.favoritesMenu(in: mainMenu, languages: Locale.preferredLanguages)
favoritesMenu?.autoenablesItems = true
favoritesMenu?.delegate = appDelegate
application.run()
