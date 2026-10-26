#!/usr/bin/env bash
# Super+C, Super+X, and Super+V copy, cut, and paste in the focused window.
# A terminal receives Ctrl+Shift, because Ctrl+C interrupts the program.
# Super+K clears the focused terminal. Kitty maps Ctrl+Shift+K to clear to the prompt.
set -euo pipefail

corebrum_edit_is_terminal() {
  local class="${1,,}"
  case "$class" in
    kitty | alacritty | foot | footclient | wezterm | ghostty | xterm | uxterm | kgx | tilix | terminator | konsole | gnome-terminal | org.gnome.terminal | org.gnome.console | org.wezfurlong.wezterm | com.mitchellh.ghostty | com.gexperts.tilix | io.elementary.terminal | org.kde.konsole | dev.warp.warp | warp)
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

corebrum_edit_class() {
  if [[ -n "${COREBRUM_EDIT_CLASS:-}" ]]; then
    printf '%s\n' "$COREBRUM_EDIT_CLASS"
    return 0
  fi
  hyprctl activewindow -j 2>/dev/null | python3 -c 'import json,sys
try:
    window = json.load(sys.stdin)
except json.JSONDecodeError:
    window = {}
print(window.get("class") or "")'
}

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

hyprctl dispatch sendshortcut "${mods},${key},active" >/dev/null
