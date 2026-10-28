#!/usr/bin/env bash
# Super+C, Super+X, and Super+V copy, cut, and paste in the focused window.
# A terminal receives Ctrl+Shift, because Ctrl+C interrupts the program.
# Super+K clears the focused terminal. Kitty maps Ctrl+Shift+K to clear to the prompt.
set -euo pipefail

corebrum_edit_is_terminal() {
  local class="${1,,}"
  case "$class" in
    kitty | alacritty | foot | footclient | wezterm | ghostty | xterm | uxterm | kgx | tilix | terminator | konsole | gnome-terminal | org.gnome.terminal | org.gnome.console | org.wezfurlong.wezterm | com.mitchellh.ghostty | com.gexperts.tilix | io.elementary.terminal | org.kde.konsole | dev.warp.warp | warp | corebrum-agent | corebrum-setup)
      return 0
      ;;
    *terminal* | *kitty* | *wezterm* | *ghostty* | *alacritty* | *konsole*)
      return 0
      ;;
  esac
  return 1
}

corebrum_edit_mods() {
  if corebrum_edit_is_terminal "$1"; then
    printf '%s\n' "CTRL SHIFT"
  else
    printf '%s\n' "CTRL"
  fi
}

corebrum_edit_key() {
  case "$1" in
    copy) printf 'C\n' ;;
    cut) printf 'X\n' ;;
    paste) printf 'V\n' ;;
    clear) printf 'K\n' ;;
    *) return 1 ;;
  esac
}

corebrum_edit_class_from_tree() {
  python3 -c '
import json
import sys

def walk(node):
    found = node if node.get("focused") else None
    for key in ("nodes", "floating_nodes"):
        for child in node.get(key) or []:
            child_found = walk(child)
            if child_found is not None:
                found = child_found
    return found

try:
    tree = json.load(sys.stdin)
except json.JSONDecodeError:
    tree = {}
window = walk(tree) or {}
props = window.get("window_properties") or {}
print(window.get("app_id") or props.get("class") or "")
'
}

corebrum_edit_class() {
  if [[ -n "${COREBRUM_EDIT_CLASS:-}" ]]; then
    printf '%s\n' "$COREBRUM_EDIT_CLASS"
    return 0
  fi
  if [[ -n "${SWAYSOCK:-}" ]] && command -v swaymsg >/dev/null 2>&1; then
    swaymsg -t get_tree | corebrum_edit_class_from_tree
    return 0
  fi
  if command -v hyprctl >/dev/null 2>&1; then
    hyprctl activewindow -j 2>/dev/null | python3 -c 'import json,sys
try:
    window = json.load(sys.stdin)
except json.JSONDecodeError:
    window = {}
print(window.get("class") or "")'
  fi
}

# Press modifiers, tap the key, then release modifiers in reverse.
# wtype's keyboard is separate from the Super key that started this shortcut.
corebrum_edit_wtype_args() {
  local mods="$1" key="${2,,}"
  local -a args=() release=()
  local mod
  for mod in $mods; do
    case "$mod" in
      CTRL) args+=(-M ctrl); release=(-m ctrl "${release[@]}") ;;
      SHIFT) args+=(-M shift); release=(-m shift "${release[@]}") ;;
    esac
  done
  args+=(-k "$key")
  if [[ ${#release[@]} -gt 0 ]]; then
    args+=("${release[@]}")
  fi
  printf '%s\n' "${args[*]}"
}

corebrum_edit_send() {
  local mods="$1" key="$2"
  local args
  if [[ -n "${SWAYSOCK:-}" ]] || ! command -v hyprctl >/dev/null 2>&1; then
    if ! command -v wtype >/dev/null 2>&1; then
      echo "corebrum-edit-keys: wtype is not installed" >&2
      return 1
    fi
    read -r -a args <<<"$(corebrum_edit_wtype_args "$mods" "$key")"
    wtype "${args[@]}" >/dev/null
    return 0
  fi
  hyprctl dispatch sendshortcut "${mods},${key},active" >/dev/null
}

if [[ "${BASH_SOURCE[0]}" != "$0" ]]; then
  return 0
fi

usage() {
  cat <<'EOF'
Usage: corebrum-edit-keys copy|cut|paste|clear
EOF
}

cmd="${1:-}"
if ! key="$(corebrum_edit_key "$cmd")"; then
  usage >&2
  exit 1
fi

class="$(corebrum_edit_class)"
if [[ "$cmd" == "clear" ]] && ! corebrum_edit_is_terminal "$class"; then
  exit 0
fi
mods="$(corebrum_edit_mods "$class")"

if [[ "${COREBRUM_EDIT_STUB:-0}" == 1 ]]; then
  printf '%s %s\n' "$mods" "$key"
  exit 0
fi

if [[ -z "$class" ]]; then
  exit 0
fi

corebrum_edit_send "$mods" "$key"
