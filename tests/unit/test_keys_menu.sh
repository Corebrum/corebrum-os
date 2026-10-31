#!/usr/bin/env bash
# Super+Space Keybindings lists the Super shortcuts and does not run them.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
menu="${ROOT}/scripts/desktop/corebrum-keys-menu.sh"
conf="${ROOT}/config/sway/config"
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
    echo "FAIL: sway config missing bind ${needle}" >&2
    fail=1
  fi
}

if ! grep -q '/usr/local/bin/corebrum-keys-menu refresh' "${ROOT}/scripts/desktop/corebrum-launcher.sh"; then
  echo "FAIL: Super+Space does not refresh Keybindings" >&2
  fail=1
fi

require_line "Super+Return           Open a terminal"
require_line "Super+K                Clear the terminal screen"
require_line "Control+Space          Transcribe the microphone"
require_line "Super+Shift+Return     Open Firefox"
require_line "Super+Shift+F          Open Files"
require_line "Super+Shift+N          Open Text Editor"
require_line "Super+W                Close the focused window"
require_line "Super+Q                Close the focused window"
require_line "Super+F                Fullscreen"
require_line "Super+T                Float or tile the focused window"
require_line "Super+C                Copy"
require_line "Super+X                Cut"
require_line "Super+V                Paste"
require_line "Super+Space            Open the application menu"
require_line "Super+Alt+Space        Open the app grid"
require_line "Super+S                Toggle the agent scratchpad terminal"
require_line "Super+Escape           Lock the screen. Type the account password and press Enter"
require_line "Super+Shift+Escape     Pause autolock, or resume it"
require_line "Super+Shift+E          Log out and return to the login screen"
require_line "Super+Shift+C          Clipboard history"
require_line "Super+Print            Record the area, camera, or audio"
require_line "Super+Shift+Print      Stop recording"
require_line "Super+P                Copy a selected area"
require_line "Super+Shift+P          Copy the whole screen"
require_line "Super+Alt+P            Record the area, camera, or audio"
require_line "Super+Alt+Shift+P      Stop recording"
require_line "Super+Arrows           Move focus to the tile in that direction"
require_line "Super+Shift+Arrows     Swap with the tile in that direction"
require_line "Super+1 … Super+5      Switch to that workspace"
require_line "Super+Shift+1 … 5      Move the focused window to that workspace"

require_bind 'bindsym $mod+Return exec /usr/local/bin/corebrum-terminal'
require_bind 'bindsym $mod+Shift+Return exec firefox'
require_bind 'bindsym $mod+Shift+f exec thunar'
require_bind 'bindsym $mod+Shift+n exec gnome-text-editor'
require_bind 'bindsym $mod+w kill'
require_bind 'bindsym $mod+q kill'
require_bind 'bindsym $mod+f fullscreen toggle'
require_bind 'bindsym $mod+t floating toggle'
require_bind 'bindsym $mod+c exec /usr/local/bin/corebrum-edit-keys copy'
require_bind 'bindsym $mod+x exec /usr/local/bin/corebrum-edit-keys cut'
require_bind 'bindsym $mod+v exec /usr/local/bin/corebrum-edit-keys paste'
require_bind 'bindsym $mod+space exec /usr/local/bin/corebrum-launcher'
require_bind 'bindsym $mod+Mod1+space exec /usr/local/bin/corebrum-grid'
require_bind 'bindsym $mod+s scratchpad show'
require_bind 'bindsym $mod+Escape exec /usr/local/bin/corebrum-lock'
require_bind 'bindsym $mod+Shift+Escape exec /usr/local/bin/corebrum-autolock toggle'
require_bind 'bindsym $mod+Shift+e exit'
require_bind 'bindsym $mod+Shift+c exec'
require_bind 'bindsym $mod+Print exec /usr/local/bin/corebrum-record start'
require_bind 'bindsym $mod+Shift+Print exec /usr/local/bin/corebrum-record stop'
require_bind 'bindsym $mod+p exec'
require_bind 'bindsym $mod+Shift+p exec'
require_bind 'bindsym $mod+Mod1+p exec /usr/local/bin/corebrum-record start'
require_bind 'bindsym $mod+Mod1+Shift+p exec /usr/local/bin/corebrum-record stop'
require_bind 'bindsym $mod+Left exec /usr/local/bin/corebrum-tile focus left'
require_bind 'bindsym $mod+Down exec /usr/local/bin/corebrum-tile focus down'
require_bind 'bindsym $mod+k exec /usr/local/bin/corebrum-edit-keys clear'
require_bind 'bindsym Ctrl+space exec "/usr/local/bin/corebrum voice hear toggle"'
if grep -q 'bindsym $mod+h exec' "$conf"; then
  echo "FAIL: Super+H still transcribes the microphone" >&2
  fail=1
fi
if grep -qE 'bindsym \$mod\+[hjl] focus' "$conf"; then
  echo "FAIL: Super+H, Super+J, or Super+L still moves focus" >&2
  fail=1
fi
require_bind 'bindsym $mod+Shift+Left exec /usr/local/bin/corebrum-tile swap left'
require_bind 'bindsym $mod+Shift+Down exec /usr/local/bin/corebrum-tile swap down'
if grep -qE 'bindsym \$mod\+Shift\+[hjkl] move' "$conf"; then
  echo "FAIL: Super+Shift+H, J, K, or L still swaps the focused tile" >&2
  fail=1
fi
require_bind 'bindsym $mod+1 workspace number 1'
require_bind 'bindsym $mod+5 workspace number 5'
require_bind 'bindsym $mod+Shift+1 move container to workspace number 1'
require_bind 'bindsym $mod+Shift+5 move container to workspace number 5'

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
