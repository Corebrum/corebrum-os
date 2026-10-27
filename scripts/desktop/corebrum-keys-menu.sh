#!/usr/bin/env bash
# Super+Space keybindings entry. Lists the Super shortcuts. Choosing a row does nothing.
set -euo pipefail

corebrum_keys_menu_lines() {
  cat <<'EOF'
Super+Return           Open a terminal
Super+K                Clear the terminal screen
Control+Space          Transcribe the microphone
Super+Shift+Return     Open Firefox
Super+Shift+F          Open Files
Super+Shift+N          Open Text Editor
Super+W                Close the focused window
Super+F                Fullscreen
Super+T                Float or tile the focused window
Super+C                Copy
Super+X                Cut
Super+V                Paste
Super+Space            Open the application menu
Super+Alt+Space        Open the app grid
Super+S                Toggle the agent scratchpad terminal
Super+Escape           Lock the screen
Super+Shift+Escape     Pause autolock, or resume it
Super+Shift+E          Log out and return to the login screen
Super+Shift+C          Clipboard history
Super+Print            Record the area, camera, or audio
Super+Shift+Print      Stop recording
Super+P                Copy a selected area
Super+Shift+P          Copy the whole screen
Super+Alt+P            Record the area, camera, or audio
Super+Alt+Shift+P      Stop recording
Super+Arrows           Move focus
Super+Shift+Arrows     Swap the focused tile
Super+1 … Super+5      Switch to that workspace
Super+Shift+1 … 5      Move the focused window to that workspace
EOF
}

corebrum_keys_menu_data_dir() {
  local root="${XDG_RUNTIME_DIR:-/tmp/corebrum-launcher-${UID}}"
  printf '%s\n' "${root}/corebrum"
}

corebrum_keys_menu_refresh() {
  local dir
  dir="$(corebrum_keys_menu_data_dir)/applications"
  mkdir -p "$dir"
  cat >"${dir}/corebrum-keys.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=Keybindings
GenericName=Keybindings
Comment=List Super keybindings
Exec=/usr/local/bin/corebrum-keys-menu open
Icon=input-keyboard
Terminal=false
Categories=Settings;
StartupNotify=false
EOF
}

corebrum_keys_menu_open() {
  if [[ "${COREBRUM_KEYS_STUB:-0}" == 1 ]]; then
    corebrum_keys_menu_lines
    return 0
  fi
  corebrum_keys_menu_lines | fuzzel \
    --config /etc/corebrum/fuzzel/fuzzel.ini \
    --dmenu \
    --prompt 'Keys  ' \
    --width 68 \
    --lines 27 >/dev/null || return 0
}

usage() {
  cat <<'EOF'
Usage: corebrum-keys-menu refresh|open|lines|data-dir
EOF
}

cmd="${1:-}"
case "$cmd" in
  refresh) corebrum_keys_menu_refresh ;;
  open) corebrum_keys_menu_open ;;
  lines) corebrum_keys_menu_lines ;;
  data-dir) corebrum_keys_menu_data_dir ;;
  -h | --help | help) usage ;;
  *)
    usage >&2
    exit 1
    ;;
esac
