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
require_line "Super+Shift+Return     Open Firefox"
require_line "Super+Shift+F          Open Files"
require_line "Super+W                Close the focused window"
require_line "Super+F                Fullscreen"
require_line "Super+V                Float or tile the focused window"
require_line "Super+Space            Open the application menu"
require_line "Super+Alt+Space        Open the app grid"
require_line "Super+S                Toggle the agent scratchpad terminal"
require_line "Super+Escape           Lock the screen"
require_line "Super+Shift+Escape     Pause autolock, or resume it"
require_line "Super+Shift+E          Leave Hyprland and return to the login screen"
require_line "Super+C                Clipboard history"
require_line "Super+Print            Record the selected area"
require_line "Super+Shift+Print      Stop recording"
require_line "Super+Arrows           Move focus"
require_line "Super+H J K L          Move focus: H left, J down, K up, L right"
require_line "Super+1 … Super+5      Switch to that workspace"
require_line "Super+Shift+1 … 5      Move the focused window to that workspace"

require_bind 'bind = $mainMod, Return, exec, /usr/local/bin/corebrum-terminal'
require_bind 'bind = $mainMod SHIFT, Return, exec, firefox'
require_bind 'bind = $mainMod SHIFT, F, exec, thunar'
require_bind 'bind = $mainMod, W, killactive'
require_bind 'bind = $mainMod, F, fullscreen'
require_bind 'bind = $mainMod, V, togglefloating'
require_bind 'bind = $mainMod, Space, exec, /usr/local/bin/corebrum-launcher'
require_bind 'bind = $mainMod ALT, Space, exec, /usr/local/bin/corebrum-grid'
require_bind 'bind = $mainMod, S, togglespecialworkspace, agent'
require_bind 'bind = $mainMod, Escape, exec, /usr/local/bin/corebrum-lock'
require_bind 'bind = $mainMod SHIFT, Escape, exec, /usr/local/bin/corebrum-autolock toggle'
require_bind 'bind = $mainMod SHIFT, E, exit'
require_bind 'bind = $mainMod, C, exec,'
require_bind 'bind = $mainMod, Print, exec,'
require_bind 'bind = $mainMod SHIFT, Print, exec,'
require_bind 'bind = $mainMod, left, movefocus, l'
require_bind 'bind = $mainMod, H, movefocus, l'
require_bind 'bind = $mainMod, J, movefocus, d'
require_bind 'bind = $mainMod, K, movefocus, u'
require_bind 'bind = $mainMod, L, movefocus, r'
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
