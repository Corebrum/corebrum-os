#!/usr/bin/env bash
# Super+Space power menu. Log out, reboot, and power off each ask again.
set -euo pipefail

corebrum_power_die() {
  printf 'corebrum-power-menu: %s\n' "$1" >&2
  exit 1
}

corebrum_power_data_dir() {
  local root="${XDG_RUNTIME_DIR:-/tmp/corebrum-launcher-${UID}}"
  printf '%s\n' "${root}/corebrum"
}

corebrum_power_lines() {
  printf '%s\n' "Log out" "Reboot" "Power off"
}

corebrum_power_confirm_lines() {
  printf '%s\n' "$1" "Cancel"
}

corebrum_power_command() {
  case "$1" in
    "Log out") printf '%s\n' "hyprctl dispatch exit" ;;
    "Reboot") printf '%s\n' "systemctl reboot" ;;
    "Power off") printf '%s\n' "systemctl poweroff" ;;
    *) return 1 ;;
  esac
}

corebrum_power_notify() {
  local summary="$1" body="$2"
  if command -v notify-send >/dev/null 2>&1; then
    notify-send --app-name=Corebrum "$summary" "$body" || true
  else
    printf 'corebrum-power-menu: %s\n' "$body" >&2
  fi
}

corebrum_power_refresh() {
  local dir
  dir="$(corebrum_power_data_dir)/applications"
  mkdir -p "$dir"
  cat >"${dir}/corebrum-power.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=Power
GenericName=Power
Comment=Log out, reboot, or power off
Keywords=sign out;shutdown;poweroff;
Exec=/usr/local/bin/corebrum-power-menu open
Icon=system-shutdown
Terminal=false
Categories=System;
StartupNotify=false
EOF
}

corebrum_power_run() {
  local action="$1"
  case "$action" in
    "Log out")
      if ! command -v hyprctl >/dev/null 2>&1; then
        corebrum_power_notify "Log out" "hyprctl is not available."
        return 1
      fi
      hyprctl dispatch exit || corebrum_power_notify "Log out" "Could not leave the session."
      ;;
    "Reboot")
      systemctl reboot || corebrum_power_notify "Reboot" "Could not reboot."
      ;;
    "Power off")
      systemctl poweroff || corebrum_power_notify "Power off" "Could not power off."
      ;;
    *)
      corebrum_power_die "unknown power choice"
      ;;
  esac
}

corebrum_power_open() {
  local choice confirm
  if [[ "${COREBRUM_POWER_STUB:-0}" == 1 && -z "${COREBRUM_POWER_CHOICE:-}" ]]; then
    corebrum_power_lines
    return 0
  fi
  if [[ "${COREBRUM_POWER_STUB:-0}" == 1 ]]; then
    choice="$COREBRUM_POWER_CHOICE"
  else
    choice="$(corebrum_power_lines | fuzzel \
      --config /etc/corebrum/fuzzel/fuzzel.ini \
      --dmenu \
      --prompt 'Power  ' \
      --width 28 \
      --lines 3)" || return 0
  fi
  [[ -n "$choice" ]] || return 0
  corebrum_power_command "$choice" >/dev/null || corebrum_power_die "unknown power choice"
  if [[ "${COREBRUM_POWER_STUB:-0}" == 1 && -z "${COREBRUM_POWER_CONFIRM:-}" ]]; then
    corebrum_power_confirm_lines "$choice"
    return 0
  fi
  if [[ "${COREBRUM_POWER_STUB:-0}" == 1 ]]; then
    confirm="$COREBRUM_POWER_CONFIRM"
  else
    confirm="$(corebrum_power_confirm_lines "$choice" | fuzzel \
      --config /etc/corebrum/fuzzel/fuzzel.ini \
      --dmenu \
      --prompt "${choice}?  " \
      --width 28 \
      --lines 2)" || return 0
  fi
  [[ "$confirm" == "$choice" ]] || return 0
  if [[ "${COREBRUM_POWER_STUB:-0}" == 1 ]]; then
    corebrum_power_command "$choice"
    return 0
  fi
  corebrum_power_run "$choice"
}

usage() {
  cat <<'EOF'
Usage: corebrum-power-menu refresh|open|lines|data-dir
EOF
}

cmd="${1:-}"
case "$cmd" in
  refresh) corebrum_power_refresh ;;
  open) corebrum_power_open ;;
  lines) corebrum_power_lines ;;
  data-dir) corebrum_power_data_dir ;;
  -h | --help | help) usage ;;
  *)
    usage >&2
    exit 1
    ;;
esac
