# Retro98

**A Windows 98–style environment for macOS that never gets in the way of your work.**

[Leia em português](README.pt-BR.md)

macOS does not allow system themes, so Retro98 isn't a theme. It's a set of reversible macOS tweaks plus original 98-style apps that run on top of macOS and live alongside it. Everything can be undone in one step.

> Inspired by Windows 98. Not affiliated with or endorsed by Microsoft. All artwork and sounds are original.

## Status

| Phase | What | State |
|---|---|---|
| 1 | Base tweaks | ✅ available |
| 2A | Visual kit + taskbar and Start menu | ✅ available |
| 2B | Window buttons on the taskbar, hidden Dock | ✅ available |
| 2C | Desktop icons | replaced by the Explorer's Desktop (the macOS desktop and widgets stay as they are) |
| 3A | Explorer: browse files | ✅ available |
| 3B | Explorer: copy, move, rename, delete | ✅ available |
| 3C | Explorer: views, search, Open With, Properties | ✅ available |
| 4 | Prompt (terminal) | ✅ available |
| 5 | Control Panel | planned |
| 6 | Notepad | planned |
| 7 | Themes for Chrome, Sublime Text and Terminal.app | planned |
| 8 | Retro web browser (WebKit) | planned |

## Requirements

- macOS 14 (Sonoma) or newer. Developed and tested on macOS 27 (Apple Silicon).
- Xcode Command Line Tools: `xcode-select --install`

## Install

```bash
git clone https://github.com/matheushchaves/retro98.git
cd retro98
./install.sh
```

The installer asks which pieces you want (base tweaks, taskbar with the Explorer, the Prompt), builds everything on your Mac (no developer account, no "unidentified developer" warning), saves the original value of every setting it is about to change, and then installs them. `./install.sh --yes` repeats your previous choices (or installs everything the first time); a new piece, like the Prompt, comes in unless you declined it before.

## Uninstall

```bash
./uninstall.sh
```

This puts back every original value. Retro98's files are removed **only** if everything was restored. If something could not be restored, the backup stays in `~/Library/Application Support/Retro98/` and you can run `./uninstall.sh` again.

## Taskbar and Start menu (Phase 2A)

A 98-style taskbar at the bottom of your main screen:

- **Start** opens the Start menu: Programs (every app on your Mac, in its folders), Documents (recently opened files), Settings (System Settings), Help, Run… (open an app, folder, document or web address by name) and Shut Down… (shut down, restart, log out or sleep).
- **Control-Escape** (⌃⎋) opens and closes the Start menu.
- The right corner shows volume, battery and the clock (hover for the date); clicking opens the matching System Settings pane.
- The Dock is hidden while the taskbar runs (it never pops up or shows labels); ⌘Tab still works. It comes back exactly as it was when you uninstall.
- If the taskbar crashes, it comes back by itself. If it crashes 3 times within a minute, it turns itself off and gives the Dock back.
- To keep the base tweaks but remove the taskbar, run `./install.sh` again and answer "n" to the taskbar question.

The first time you use Shut Down…, macOS asks whether Retro98 Shell may control System Events.

## Window buttons (Phase 2B)

- One button per open window on the current Space, with the app's icon and the window title.
- Click a button to bring its window forward; click the active window's button to minimize it; click a minimized window's button to restore it.
- Right-click a button for Restore, Minimize and Close.
- Maximized, "Fill" and tiled windows stop at the top of the taskbar instead of going under it.

These need **Accessibility** permission. The first time, Retro98 Shell explains and opens System Settings › Privacy & Security › Accessibility: turn on Retro98 Shell. You only do this once: the installer signs the Shell with a local certificate (kept in its own keychain, `~/Library/Keychains/retro98-signing.keychain-db`), so macOS remembers the permission across updates. Uninstalling removes that keychain; you can also remove Retro98 Shell from the Accessibility list.

## Explorer (Phase 3)

Retro98 Explorer is a 98-style file manager installed with the taskbar (`~/Applications/Retro98/Retro98 Explorer.app`). It's a separate app: Finder keeps working as always.

- Open it from the quick launch button next to Start, from Start › Programs › Retro98 › Retro98 Explorer, or with a link: `open retro98-explorer://desktop` (also `retro98-explorer://my-computer` and `retro98-explorer://folder?path=/Applications`).
- It opens on the **Desktop**: My Computer, My Documents, Recycle Bin and the files in your Desktop folder. Your macOS desktop and widgets are not touched.
- On screen: folder tree on the left, toolbar, address bar and status bar (objects, selection size, free space). In the address bar, type a path (`~/Downloads`) or a place name ("My Computer"); its arrow lists the folders above the current one.
- My Computer lists your disks, USB drives and network volumes, and updates when you plug one in or eject it. Open folders refresh by themselves when their files change.
- Double-click, ⌘O or ⌘↓ opens: folders open in place, files and apps open in their usual macOS app. The space bar previews the selection with Quick Look.

### Viewing and searching (3C)

- **Views:** large icons, small icons, list and details (⌘1 to ⌘4, the View menu or the Views button). The list scrolls sideways. In Details, the Name, Size, Type and Modified columns sort with a click, and a second click reverses; View › Arrange by… does the same in the other views. The view and the order apply to every window and are remembered.
- **Hidden files:** View › Show Hidden Files (⇧⌘.). They show faded, as in 98.
- **Search** (⌘F): opens the "Search for" bar under the address. Typing filters the folder right away; with **Include subfolders**, the search goes into subfolders in the background (up to 5,000 results) and Details gains an "In Folder" column. **Stop** interrupts and Esc closes. **Start › Find…** opens a window already searching your home folder.
- **Properties** (⌘I or ⌥↩︎): type, location, size (computed in the background for folders), what a folder contains and the dates. For disks and USB drives, used and free space.
- **Open With:** right-click › Open With, with the default app first and "Other…" to pick any app. Also in File › Open With….
- **Eject** (⌘E): in My Computer, for USB drives and network volumes. If the disk is in use, the reason shows up.

### Working with files (3B)

- **Copy, cut and paste** work together with Finder: copy on one side and paste on the other. A cut item looks faded until you paste, and pasting moves it. **⌥⌘V** moves what was copied (in the Explorer or in Finder), like Finder's "Move Item Here".
- **Drag and drop** between Explorer windows, to and from Finder, and from other apps (photos from Photos, Mail attachments). On the same disk a drag moves; to another disk it copies. Hold **⌥** to copy or **⌘** to move. Dropping on a folder, My Documents, a disk or the Recycle Bin sends the items there.
- **Rename** with **Enter** or **F2** (or the context menu). The name without its extension comes selected; changing the extension asks first. **New Folder** (⇧⌘N) starts out renaming.
- **Delete** (⌘⌫ or Del) asks, then sends to the macOS Trash. **Delete Permanently** (⌥⌘⌫ or ⇧Del) asks, then deletes for good. In the Recycle Bin window, **Restore** puts items back where they came from, and **Empty Recycle Bin** (⇧⌘⌫) asks, then empties it.
- **Replace:** when an item with the same name exists, the Explorer asks (Yes, Yes to All, No, Cancel) and shows the size and date of both. The replaced item goes to the Trash; it doesn't vanish.
- **Long operations** show a progress dialog with Cancel; the window stays usable meanwhile. Cancelling never leaves a half-copied file.
- **Undo** (⌘Z, or the Undo button) covers the whole app: it undoes paste, move, rename, new folder, delete and restore; ⇧⌘Z redoes. Undoing a copy sends the copy to the Trash, as in Finder.
- Right-click opens the context menu for an item or the window background.
- Limits: "Restore" only knows what the Explorer itself sent to the Trash (the rest goes back with Finder's "Put Back"; macOS doesn't offer that to other apps). The Recycle Bin window shows and empties only your disk's Trash; Finder empties items deleted from USB drives. Dragging from Photos or Mail isn't undoable.
- **Full Disk Access (optional, only for the Recycle Bin):** macOS protects the Trash folder: seeing it needs this, and restoring, emptying or undoing a delete may need it. The installer opens System Settings › Privacy & Security › Full Disk Access and shows the app in Finder: turn on Retro98 Explorer (or drag it into the list). Without it, the Recycle Bin window offers "Open in Finder".

### Explorer shortcuts

| Action | Keys |
|---|---|
| Back, Forward, Up | ⌘[ · ⌘] · ⌘↑ or Backspace |
| Open | double-click, ⌘O or ⌘↓ |
| Desktop, My Computer, My Documents, Downloads | ⇧⌘D · ⇧⌘C · ⇧⌘O · ⌥⌘L |
| Large icons, small icons, list, details | ⌘1 · ⌘2 · ⌘3 · ⌘4 |
| Show hidden files | ⇧⌘. |
| Search | ⌘F (Esc closes) |
| Properties | ⌘I or ⌥↩︎ |
| Eject | ⌘E |
| Copy, cut, paste | ⌘C · ⌘X · ⌘V |
| Move what was copied | ⌥⌘V |
| Undo, redo | ⌘Z · ⇧⌘Z |
| New folder | ⇧⌘N |
| Rename | Enter or F2 |
| Send to the Recycle Bin | ⌘⌫ or Del |
| Delete permanently | ⌥⌘⌫ or ⇧Del |
| Empty Recycle Bin | ⇧⌘⌫ |
| Refresh, new window, close, select all | ⌘R · ⌘N · ⌘W · ⌘A |

### Explorer instead of Finder (optional)

When another app asks to "Show in Finder" (Safari's downloads, for example), macOS can open Retro98 Explorer instead, with the file already selected.

- **Turn on:** the installer asks when you choose the taskbar; the default answer is No.
- **Turn off:** run `./install.sh` again and answer No, or uninstall. Finder is put back before the Explorer leaves the disk.
- **Limits:** apps that were already open may need to be reopened to notice the change. Opening a folder with a double-click in other apps still goes to Finder. A switch in the Control Panel comes in Phase 5.

## Prompt (Phase 4)

Retro98 Prompt is a full terminal in a 98-style window (`~/Applications/Retro98/Retro98 Prompt.app`): light gray text on black in a classic VGA font, drawn pixel-sharp. It runs your own shell (`$SHELL`, as a login shell, like Terminal), so your aliases, prompt and tools are all there.

- **Open it** from Start › Programs › Retro98 › Retro98 Prompt, from Spotlight, or with `open -a "Retro98 Prompt"`. The installer asks about it separately from the taskbar (default Yes).
- **Windows, not tabs:** ⌘N opens another window; each one is its own shell. Closing a window (⌘W, or the × button) while a program runs (vim, ssh, a build) asks first; an idle shell closes right away, and typing `exit` closes the window. Quitting asks once if any window has a program running.
- **Everyday terminal things:** copy and paste with ⌘C/⌘V (select with the mouse), 10,000 lines of scrollback with the retro scroll bar or the trackpad, ANSI and 256 colors, Unicode and accents. Option types characters (é, ã, ü) instead of acting as Meta. Resize the window and the lines follow.
- **It doesn't replace Terminal:** Terminal stays the app that opens `.command` and `.sh` files, and nothing about it changes. A Terminal profile with the same look comes in Phase 7.

| Action | Shortcut |
|---|---|
| New window, close | ⌘N · ⌘W |
| Copy, paste, select all | ⌘C · ⌘V · ⌘A |
| Minimize | ⌘M |

## What Phase 1 changes

| Id | Tweak | What changes |
|---|---|---|
| `wallpaper` | Solid teal desktop | Wallpaper becomes solid `#008080` on every screen |
| `lightAppearance` | Light mode | Light appearance, automatic switching off |
| `colors` | Graphite accent and navy selection | Graphite accent color, `#000080` text selection |
| `contrast` | Reduced transparency and increased contrast | Opaque menus and sidebars, outlined controls |
| `pointer` | White pointer with black outline | Pointer fill white, outline black |
| `scrollBars` | Always-visible scroll bars | Scroll bars never auto-hide |
| `windowAnimations` | No window animations | Windows open and close instantly |
| `titleBarDoubleClick` | Double-click title bar to maximize | Double-click fills the screen |
| `finderExplorer` | Explorer-like Finder | Status bar, path bar, all file extensions, folders first, list view, new windows open your home folder |

Apply or undo individual tweaks with the installed tool:

```bash
TOOL="$HOME/Library/Application Support/Retro98/bin/retro98-settings"
"$TOOL" status
"$TOOL" apply --only colors,pointer
"$TOOL" restore --only lightAppearance
```

## Permissions and known issues

- To switch to light mode right away, macOS may ask whether **Terminal can control System Events**. If you decline, light mode still takes effect after you log out and back in.
- The Accessibility tweaks (`contrast`, `pointer`) need **Full Disk Access** for the terminal app you run the installer from. If macOS refuses them, the tool opens **System Settings › Privacy & Security › Full Disk Access**: turn on your terminal app and run the same command again. Every other tweak still gets applied. Use the same terminal app to uninstall.
- Some apps only show the new colors, scroll bars or animation setting after you quit and reopen them.

## Credits

- **Prompt font:** PxPlus IBM VGA 8x16 from [The Ultimate Oldschool PC Font Pack](https://int10h.org/oldschool-pc-fonts/) by VileR, licensed under [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/). The font and its license travel in `Resources/Prompt/` and inside the app. It's the "Plus" version because the original code page 437 one has no ã or õ.
- **Terminal engine:** [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm) by Miguel de Icaza, MIT license, vendored at 1.11.2 in `Vendor/SwiftTerm` with three small fixes taken from SwiftTerm 1.19 (crisp pixel fonts, room for our own scroll bar, noticing the shell's exit). Newer versions need Xcode's separately downloaded Metal Toolchain to build, which would break the install on most Macs; `Vendor/SwiftTerm/VENDORED.md` has the details.

## License

[MIT](LICENSE) for Retro98's own code. The Prompt font keeps its CC BY-SA 4.0 license and SwiftTerm its MIT license.
