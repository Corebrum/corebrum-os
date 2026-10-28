#!/usr/bin/env bash
# Super+C/X/V send Ctrl in applications and Ctrl+Shift in a terminal.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
edit="${ROOT}/scripts/desktop/corebrum-edit-keys.sh"
conf="${ROOT}/config/kitty/kitty.conf"
# shellcheck source=../../scripts/desktop/corebrum-edit-keys.sh
source "$edit"
fail=0

chord() {
  COREBRUM_EDIT_STUB=1 COREBRUM_EDIT_CLASS="$1" bash "$edit" "$2"
}

expect() {
  local got="$1"
  local want="$2"
  local label="$3"
  if [[ "$got" != "$want" ]]; then
    echo "FAIL: ${label}: got '${got}', want '${want}'" >&2
    fail=1
  fi
}

expect "$(chord firefox copy)" "CTRL C" "firefox copy"
expect "$(chord firefox cut)" "CTRL X" "firefox cut"
expect "$(chord firefox paste)" "CTRL V" "firefox paste"
expect "$(chord kitty copy)" "CTRL SHIFT C" "kitty copy"
expect "$(chord kitty cut)" "CTRL SHIFT X" "kitty cut"
expect "$(chord kitty paste)" "CTRL SHIFT V" "kitty paste"
expect "$(chord org.wezfurlong.wezterm paste)" "CTRL SHIFT V" "wezterm paste"
expect "$(chord org.gnome.Console copy)" "CTRL SHIFT C" "gnome console copy"
expect "$(chord kitty clear)" "CTRL SHIFT K" "kitty clear"
expect "$(chord org.gnome.Terminal clear)" "CTRL SHIFT K" "gnome terminal clear"
expect "$(chord firefox clear)" "" "firefox clear"
expect "$(chord corebrum-agent copy)" "CTRL SHIFT C" "agent terminal copy"
expect "$(chord corebrum-setup paste)" "CTRL SHIFT V" "setup terminal paste"
expect "$(corebrum_edit_wtype_args "CTRL" C)" "-M ctrl -k c -m ctrl" "application chord"
expect "$(corebrum_edit_wtype_args "CTRL SHIFT" V)" "-M ctrl -M shift -k v -m shift -m ctrl" "terminal chord"

kitty_tree='{"nodes":[{"type":"con","focused":false,"app_id":null,"nodes":[{"type":"con","focused":true,"app_id":"kitty","nodes":[]}]}]}'
x11_tree='{"nodes":[{"type":"con","focused":true,"app_id":null,"window_properties":{"class":"Firefox"},"nodes":[]}]}'
expect "$(printf '%s' "$kitty_tree" | corebrum_edit_class_from_tree)" "kitty" "sway kitty app id"
expect "$(printf '%s' "$x11_tree" | corebrum_edit_class_from_tree)" "Firefox" "xwayland class"

if ! grep -q 'wtype' "$edit"; then
  echo "FAIL: copy still depends on Hyprland sendshortcut" >&2
  fail=1
fi
if ! grep -qx 'wtype' "${ROOT}/manifests/packages/desktop.txt"; then
  echo "FAIL: the desktop profile does not install wtype" >&2
  fail=1
fi

if ! grep -q 'map ctrl+shift+x combine : copy_to_clipboard : clear_selection' "$conf"; then
  echo "FAIL: kitty does not cut the selection on Ctrl+Shift+X" >&2
  fail=1
fi
if ! grep -q 'map ctrl+shift+k clear_terminal to_cursor active' "$conf"; then
  echo "FAIL: kitty does not clear to the prompt on Ctrl+Shift+K" >&2
  fail=1
fi

if [[ "$fail" -ne 0 ]]; then
  exit 1
fi
echo "edit key unit tests passed"
