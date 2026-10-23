#!/usr/bin/env bash
# Super+C/X/V send Ctrl in applications and Ctrl+Shift in a terminal.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
edit="${ROOT}/scripts/desktop/corebrum-edit-keys.sh"
conf="${ROOT}/config/kitty/kitty.conf"
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

if ! grep -q 'map ctrl+shift+x combine : copy_to_clipboard : clear_selection' "$conf"; then
  echo "FAIL: kitty does not cut the selection on Ctrl+Shift+X" >&2
  fail=1
fi

if [[ "$fail" -ne 0 ]]; then
  exit 1
fi
echo "edit key unit tests passed"
