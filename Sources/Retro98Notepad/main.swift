import AppKit
import Retro98Settings
import Retro98UI

// Retro98's sounds follow the Control Panel's switch, read each time one plays.
RetroSound.isEnabled = { ChoicesFile.live().load().soundsOn }
let application = NSApplication.shared
let appDelegate = AppDelegate()
application.delegate = appDelegate
application.setActivationPolicy(.regular)
let mainMenu = NotepadMenus.mainMenu(languages: Locale.preferredLanguages)
application.mainMenu = mainMenu
application.windowsMenu = NotepadMenus.windowMenu(in: mainMenu, languages: Locale.preferredLanguages)
application.run()
