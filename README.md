# Retro98

**A Windows 98–style environment for macOS that never gets in the way of your work.**

[Leia em português](README.pt-BR.md)

macOS does not allow system themes, so Retro98 isn't a theme. It's a set of reversible macOS tweaks plus original 98-style apps that run on top of macOS and live alongside it. Everything can be undone in one step.

> Inspired by Windows 98. Not affiliated with or endorsed by Microsoft. All artwork and sounds are original.

## Status

| Phase | What | State |
|---|---|---|
| 1 | Base tweaks (this release) | ✅ available |
| 2 | Visual kit + Shell (desktop, taskbar, Start menu) | planned |
| 3 | Explorer (file manager) | planned |
| 4 | Prompt (terminal) | planned |
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

The installer builds everything on your Mac (no developer account, no "unidentified developer" warning), saves the original value of every setting it is about to change, and then applies the Phase 1 tweaks. Use `./install.sh --yes` to skip the question.

## Uninstall

```bash
./uninstall.sh
```

This puts back every original value. Retro98's files are removed **only** if everything was restored. If something could not be restored, the backup stays in `~/Library/Application Support/Retro98/` and you can run `./uninstall.sh` again.

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
- If macOS refuses an Accessibility setting (`contrast`, `pointer`), the tool opens **System Settings › Accessibility › Display** so you can change it by hand. Every other tweak still gets applied.
- Some apps only show the new colors, scroll bars or animation setting after you quit and reopen them.

## License

[MIT](LICENSE)
