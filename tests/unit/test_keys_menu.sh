#!/usr/bin/env bash
# Super+Space Keybindings lists the Super shortcuts and does not run them.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
menu="${ROOT}/scripts/desktop/corebrum-keys-menu.sh"
conf="${ROOT}/config/hypr/hyprland.conf"
fail=0

require_line() {
  local needle="$1"
  if ! grep -qxF -- "$needle" <(bash "$menu" lines); then
    echo "FAIL: key list missing: ${needle}" >&2
    fail=1
  fi
}

require_bind() {
  local needle="$1"
  if ! grep -qF -- "$needle" "$conf"; then
    echo "FAIL: hyprland.conf missing bind ${needle}" >&2
    fail=1
  fi
}

if ! grep -q '/usr/local/bin/corebrum-keys-menu refresh' "${ROOT}/scripts/desktop/corebrum-launcher.sh"; then
  echo "FAIL: Super+Space does not refresh Keybindings" >&2
  fail=1
fi

require_line "Super+Return           Open a terminal"
require_line "Super+K                Clear the terminal screen"
require_line "Super+Shift+Return     Open Firefox"
require_line "Super+Shift+F          Open Files"
require_line "Super+Shift+N          Open Text Editor"
require_line "Super+W                Close the focused window"
require_line "Super+F                Fullscreen"
require_line "Super+T                Float or tile the focused window"
require_line "Super+C                Copy"
require_line "Super+X                Cut"
require_line "Super+V                Paste"
require_line "Super+Space            Open the application menu"
require_line "Super+Alt+Space        Open the app grid"
require_line "Super+S                Toggle the agent scratchpad terminal"
require_line "Super+Escape           Lock the screen"
require_line "Super+Shift+Escape     Pause autolock, or resume it"
require_line "Super+Shift+E          Log out and return to the login screen"
require_line "Super+Shift+C          Clipboard history"
require_line "Super+Print            Record the area, camera, or audio"
require_line "Super+Shift+Print      Stop recording"
require_line "Super+P                Copy a selected area"
require_line "Super+Shift+P          Copy the whole screen"
require_line "Super+Alt+P            Record the area, camera, or audio"
require_line "Super+Alt+Shift+P      Stop recording"
require_line "Super+Arrows           Move focus"
require_line "Super+Shift+Arrows     Swap the focused tile"
require_line "Super+1 … Super+5      Switch to that workspace"
require_line "Super+Shift+1 … 5      Move the focused window to that workspace"

require_bind 'bind = $mainMod, Return, exec, /usr/local/bin/corebrum-terminal'
require_bind 'bind = $mainMod SHIFT, Return, exec, firefox'
require_bind 'bind = $mainMod SHIFT, F, exec, thunar'
require_bind 'bind = $mainMod SHIFT, N, exec, gnome-text-editor'
require_bind 'bind = $mainMod, W, killactive'
require_bind 'bind = $mainMod, F, fullscreen'
require_bind 'bind = $mainMod, T, togglefloating'
require_bind 'bind = $mainMod, C, exec, /usr/local/bin/corebrum-edit-keys copy'
require_bind 'bind = $mainMod, X, exec, /usr/local/bin/corebrum-edit-keys cut'
require_bind 'bind = $mainMod, V, exec, /usr/local/bin/corebrum-edit-keys paste'
require_bind 'bind = $mainMod, Space, exec, /usr/local/bin/corebrum-launcher'
require_bind 'bind = $mainMod ALT, Space, exec, /usr/local/bin/corebrum-grid'
require_bind 'bind = $mainMod, S, togglespecialworkspace, agent'
require_bind 'bind = $mainMod, Escape, exec, /usr/local/bin/corebrum-lock'
require_bind 'bind = $mainMod SHIFT, Escape, exec, /usr/local/bin/corebrum-autolock toggle'
require_bind 'bind = $mainMod SHIFT, E, exit'
require_bind 'bind = $mainMod SHIFT, C, exec,'
require_bind 'bind = $mainMod, Print, exec, /usr/local/bin/corebrum-record start'
require_bind 'bind = $mainMod SHIFT, Print, exec, /usr/local/bin/corebrum-record stop'
require_bind 'bind = $mainMod, P, exec,'
require_bind 'bind = $mainMod SHIFT, P, exec,'
require_bind 'bind = $mainMod ALT, P, exec, /usr/local/bin/corebrum-record start'
require_bind 'bind = $mainMod ALT SHIFT, P, exec, /usr/local/bin/corebrum-record stop'
require_bind 'bind = $mainMod, left, movefocus, l'
require_bind 'bind = $mainMod, K, exec, /usr/local/bin/corebrum-edit-keys clear'
if grep -qE 'bind = \$mainMod, [HJL], movefocus' "$conf"; then
  echo "FAIL: Super+H, Super+J, or Super+L still moves focus" >&2
  fail=1
fi
require_bind 'bind = $mainMod SHIFT, left, swapwindow, l'
if grep -qE 'bind = \$mainMod SHIFT, [HJKL], swapwindow' "$conf"; then
  echo "FAIL: Super+Shift+H, J, K, or L still swaps the focused tile" >&2
  fail=1
fi
require_bind 'bind = $mainMod, 1, workspace, 1'
require_bind 'bind = $mainMod, 5, workspace, 5'
require_bind 'bind = $mainMod SHIFT, 1, movetoworkspace, 1'
require_bind 'bind = $mainMod SHIFT, 5, movetoworkspace, 5'

runtime="$(mktemp -d)"
export XDG_RUNTIME_DIR="$runtime"
export COREBRUM_KEYS_STUB=1
bash "$menu" refresh
desktop="${runtime}/corebrum/applications/corebrum-keys.desktop"
if ! grep -q '^Name=Keybindings$' "$desktop"; then
  echo "FAIL: desktop entry is not named Keybindings" >&2
  fail=1
fi
if ! grep -q '^Exec=/usr/local/bin/corebrum-keys-menu open$' "$desktop"; then
  echo "FAIL: desktop entry does not open the key list" >&2
  fail=1
fi
if grep -q 'exec ' <(bash "$menu" open); then
  echo "FAIL: the key list offers a command to run" >&2
  fail=1
fi

rm -rf "$runtime"
if [[ "$fail" -ne 0 ]]; then
  exit 1
fi
echo "keybindings menu unit tests passed"
