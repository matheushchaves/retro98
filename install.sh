#!/usr/bin/env bash
# Builds Retro98 on this Mac and installs the chosen pieces: base tweaks, the taskbar (Shell), the Prompt, the
# Notepad and the themes for other apps, plus the Control Panel, where they are turned on and off later.
# Every setting it changes is backed up first; ./uninstall.sh puts everything back.
set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/scripts/common.sh"

MINIMUM_MACOS=14
ASSUME_YES=false

usage() {
    say "Uso: ./install.sh [--yes]" "Usage: ./install.sh [--yes]"
}

for arg in "$@"; do
    case "$arg" in
        --yes|-y) ASSUME_YES=true ;;
        --help|-h) usage; exit 0 ;;
        *) usage; exit 1 ;;
    esac
done

macos_major="$(sw_vers -productVersion | cut -d. -f1)"
if (( macos_major < MINIMUM_MACOS )); then
    say "O Retro98 precisa do macOS $MINIMUM_MACOS ou mais novo." "Retro98 needs macOS $MINIMUM_MACOS or newer."
    exit 1
fi

if ! xcode-select -p > /dev/null 2>&1; then
    say "Instale as Ferramentas de Linha de Comando do Xcode e rode de novo: xcode-select --install" \
        "Install the Xcode Command Line Tools and run again: xcode-select --install"
    exit 1
fi

# ask "pergunta" "question" → 0 for yes (default), 1 for no
ask() {
    local answer
    read -r -p "$(say "$1 [S/n] " "$2 [Y/n] ")" answer
    [[ "${answer:-}" != [nN]* ]]
}

# Like ask, but an empty answer means no.
ask_no() {
    local answer
    read -r -p "$(say "$1 [s/N] " "$2 [y/N] ")" answer
    [[ "${answer:-}" == [sSyY]* ]]
}

pieces=""
if $ASSUME_YES; then
    pieces="$(cat "$PIECES_FILE" 2>/dev/null || echo "base shell prompt notepad themes")"
    # Pieces saved before the Prompt, the Notepad or the themes existed get them: a new piece arrives on unless it was declined.
    [[ " $pieces " == *" prompt "* || " $pieces " == *" noprompt "* ]] || pieces+=" prompt"
    [[ " $pieces " == *" notepad "* || " $pieces " == *" nonotepad "* ]] || pieces+=" notepad"
    [[ " $pieces " == *" themes "* || " $pieces " == *" nothemes "* ]] || pieces+=" themes"
elif [[ ! -t 0 ]]; then
    say "Sem terminal interativo: rode ./install.sh --yes para aplicar." \
        "No interactive terminal: run ./install.sh --yes to apply."
    exit 1
else
    ask "Instalar os ajustes base?" "Install the base tweaks?" && pieces+=" base"
    ask "Instalar a barra de tarefas e o menu Iniciar?" "Install the taskbar and Start menu?" && pieces+=" shell"
    if [[ " $pieces " == *" shell "* ]]; then
        ask_no "Usar o Retro98 Explorer no lugar do Finder quando outros apps pedem \"Mostrar no Finder\"? (opcional)" \
            "Use Retro98 Explorer instead of Finder when other apps ask to \"Show in Finder\"? (optional)" && pieces+=" fileviewer"
    fi
    if ask "Instalar o Prompt (terminal retrô)?" "Install the Prompt (retro terminal)?"; then
        pieces+=" prompt"
    else
        pieces+=" noprompt"
    fi
    if ask "Instalar o Bloco de Notas?" "Install the Notepad?"; then
        pieces+=" notepad"
    else
        pieces+=" nonotepad"
    fi
    if ask "Instalar os temas para Chrome, Sublime Text e Terminal?" "Install the themes for Chrome, Sublime Text and Terminal?"; then
        pieces+=" themes"
    else
        pieces+=" nothemes"
    fi
fi
pieces="$(echo $pieces)"

# The Shell and the Explorer travel together (the taskbar's quick launch button opens the Explorer).
build_shell_apps() {
    # Build first: if it fails, nothing (the Dock included) has been changed yet.
    say "Montando o Retro98 Shell..." "Building Retro98 Shell..."
    "${RETRO98_BUILD_SHELL_APP:-$RETRO98_ROOT/scripts/build-shell-app.sh}" "$SHELL_APP"
    say "Montando o Retro98 Explorer..." "Building Retro98 Explorer..."
    "$RETRO98_ROOT/scripts/build-app.sh" Retro98Explorer "$EXPLORER_ID" "Retro98 Explorer" "$EXPLORER_APP" regular \
        "$EXPLORER_SCHEME" explorer
    # Registered before the Shell starts, so its quick launch button finds the Explorer.
    "$LSREGISTER" -f "$EXPLORER_APP" || status=$?
}

# "Show in Finder" opens the Explorer only when that piece was chosen.
apply_fileviewer_choice() {
    if [[ " $pieces " == *" fileviewer "* ]]; then
        "$BIN" apply --only explorerFileViewer || status=$?
    else
        "$BIN" restore --only explorerFileViewer || status=$?
    fi
}

if [[ -n "${RETRO98_SETTINGS_BIN:-}" ]]; then
    BIN="$RETRO98_SETTINGS_BIN"
else
    say "Compilando o Retro98..." "Building Retro98..."
    (cd "$RETRO98_ROOT" && swift build -c release --product retro98-settings)
    mkdir -p "$SUPPORT_DIR/bin"
    cp "$RETRO98_ROOT/.build/release/retro98-settings" "$INSTALLED_BIN"
    BIN="$INSTALLED_BIN"
fi

mkdir -p "$SUPPORT_DIR"
echo "$pieces" > "$PIECES_FILE"
status=0

if [[ " $pieces " == *" base "* ]]; then
    "$BIN" apply || status=$?
fi

if [[ " $pieces " == *" shell "* ]]; then
    build_shell_apps
    "$BIN" apply --only dockUnderTaskbar || status=$?
    mkdir -p "$LAUNCH_AGENTS_DIR"
    # Same keys as ShellAgent.plist in Retro98Settings (the Control Panel's switch); keep the two in step.
    cat > "$LAUNCH_AGENT_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key><string>$SHELL_LABEL</string>
    <key>ProgramArguments</key><array><string>$SHELL_APP/Contents/MacOS/Retro98Shell</string></array>
    <key>RunAtLoad</key><true/>
    <key>KeepAlive</key><dict><key>SuccessfulExit</key><false/></dict>
    <key>ThrottleInterval</key><integer>5</integer>
    <key>ProcessType</key><string>Interactive</string>
</dict>
</plist>
PLIST
    stop_shell_processes
    # A previous crash-loop give-up disables the agent; installing turns it back on.
    launchctl enable "gui/$(id -u)/$SHELL_LABEL" || true
    launchctl bootstrap "gui/$(id -u)" "$LAUNCH_AGENT_PLIST" || status=$?
    say "Na primeira vez, o Retro98 Shell vai pedir a permissão de Acessibilidade para mostrar as janelas na barra. Ative-o em Ajustes do Sistema › Privacidade e Segurança › Acessibilidade." \
        "The first time, Retro98 Shell asks for Accessibility permission to show your windows on the taskbar. Turn it on in System Settings › Privacy & Security › Accessibility."
    say "Para o Explorer mostrar, restaurar e esvaziar a Lixeira, dê Acesso Total ao Disco só ao Retro98 Explorer em Ajustes do Sistema › Privacidade e Segurança › Acesso Total ao Disco (opcional; o resto funciona sem isso, e o Retro98 Shell não precisa)." \
        "For the Explorer to show, restore and empty the Recycle Bin, give only Retro98 Explorer Full Disk Access in System Settings › Privacy & Security › Full Disk Access (optional; everything else works without it, and Retro98 Shell doesn't need it)."
    open "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles" || true
    open -R "$EXPLORER_APP" || true
    apply_fileviewer_choice
elif [[ " $pieces " == *" shelloff "* ]]; then
    # Turned off in the Control Panel: keep both apps current, the taskbar off and the Dock normal.
    build_shell_apps
    stop_shell
    "$BIN" restore --only dockUnderTaskbar || status=$?
    apply_fileviewer_choice
elif [[ -f "$LAUNCH_AGENT_PLIST" || -d "$SHELL_APP" || -d "$EXPLORER_APP" ]]; then
    # The taskbar was installed before and now wasn't chosen: turn it off and give the Dock back.
    stop_shell
    rm -rf "$SHELL_APP"
    # "Show in Finder" must point back at Finder before the Explorer leaves the disk.
    "$BIN" restore --only explorerFileViewer || status=$?
    remove_explorer
    "$BIN" restore --only dockUnderTaskbar || status=$?
fi

if [[ " $pieces " == *" prompt "* ]]; then
    say "Montando o Retro98 Prompt..." "Building Retro98 Prompt..."
    # macOS asks on the Prompt's behalf when a program run in it (osascript, say) wants to control another app.
    "$RETRO98_ROOT/scripts/build-app.sh" Retro98Prompt "$PROMPT_ID" "Retro98 Prompt" "$PROMPT_APP" regular "" prompt \
        "Programs you run in Retro98 Prompt (scripts that use osascript, for example) can ask to control other apps." \
        "$RETRO98_ROOT/Resources/Fonts"
    # Registered so Spotlight and `open -a "Retro98 Prompt"` find it right away.
    "$LSREGISTER" -f "$PROMPT_APP" || status=$?
else
    remove_prompt
fi

if [[ " $pieces " == *" notepad "* ]]; then
    say "Montando o Retro98 Notepad..." "Building Retro98 Notepad..."
    # Plain text as a document type lists the Notepad in "Open With" without making it the default app.
    "$RETRO98_ROOT/scripts/build-app.sh" Retro98Notepad "$NOTEPAD_ID" "Retro98 Notepad" "$NOTEPAD_APP" regular "" notepad "" \
        "$RETRO98_ROOT/Resources/Fonts" "public.plain-text"
    "$LSREGISTER" -f "$NOTEPAD_APP" || status=$?
else
    remove_notepad
fi

if [[ " $pieces " == *" themes "* ]]; then
    say "Preparando os temas..." "Preparing the themes..."
    if ! install_themes; then
        say "Não foi possível preparar os temas. O resto da instalação continua." \
            "Couldn't prepare the themes. The rest of the install goes on."
        status=1
    fi
else
    remove_themes || true
fi

say "Montando o Retro98 Control Panel..." "Building Retro98 Control Panel..."
# The light/dark switch goes through System Events, which macOS asks about on the Control Panel's behalf.
"$RETRO98_ROOT/scripts/build-app.sh" Retro98ControlPanel "$CONTROL_PANEL_ID" "Retro98 Control Panel" "$CONTROL_PANEL_APP" regular "" \
    controlpanel "Retro98 Control Panel uses System Events to switch between light and dark mode right away."
"$LSREGISTER" -f "$CONTROL_PANEL_APP" || status=$?

say "Para ver o estado: \"$BIN\" status · Para desfazer tudo: ./uninstall.sh" \
    "To check: \"$BIN\" status · To undo everything: ./uninstall.sh"
exit $status
