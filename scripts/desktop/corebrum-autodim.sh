#!/usr/bin/env bash
# Super+Space auto dim timer, independent of Autolock.
set -euo pipefail

COREBRUM_AUTODIM_INSTALL_MARK='   install'
COREBRUM_AUTODIM_ON_MARK='   on'

corebrum_autodim_die() {
  printf 'corebrum-autodim: %s\n' "$1" >&2
  exit 1
}

corebrum_autodim_state_dir() {
  local root="${XDG_STATE_HOME:-${HOME}/.local/state}"
  printf '%s\n' "${root}/corebrum"
}

corebrum_autodim_runtime_dir() {
  local root="${XDG_RUNTIME_DIR:-/tmp/corebrum-autodim-${UID}}"
  printf '%s\n' "${root}/corebrum"
}

corebrum_autodim_data_dir() {
  corebrum_autodim_runtime_dir
}

corebrum_autodim_ready() {
  if [[ "${COREBRUM_AUTODIM_STUB:-0}" == 1 ]]; then
    [[ "${COREBRUM_AUTODIM_READY:-0}" == 1 ]]
    return
  fi
  command -v swayidle >/dev/null 2>&1
}

corebrum_autodim_minutes() {
  local file minutes
  if [[ -n "${COREBRUM_AUTODIM_MINUTES:-}" ]]; then
    minutes="$COREBRUM_AUTODIM_MINUTES"
  else
    file="$(corebrum_autodim_state_dir)/autodim-minutes"
    if [[ -f "$file" ]]; then
      minutes="$(tr -d '[:space:]' <"$file")"
    else
      minutes=0
    fi
  fi
  case "$minutes" in
    0 | 5 | 10 | 30 | 60) printf '%s\n' "$minutes" ;;
    *) printf '0\n' ;;
  esac
}

corebrum_autodim_label() {
  local minutes="$1"
  if [[ "$minutes" == 60 ]]; then
    printf '1 hour\n'
  elif [[ "$minutes" == 0 ]]; then
    printf 'Off\n'
  else
    printf '%s minutes\n' "$minutes"
  fi
}

corebrum_autodim_entry_name() {
  if corebrum_autodim_ready; then
    printf 'Auto dim\n'
  else
    printf 'Auto dim%s\n' "$COREBRUM_AUTODIM_INSTALL_MARK"
  fi
}

corebrum_autodim_lines() {
  local minutes current label marked
  minutes="$(corebrum_autodim_minutes)"
  for current in 0 5 10 30 60; do
    label="$(corebrum_autodim_label "$current")"
    if [[ "$current" == "$minutes" ]]; then
      marked="${label}${COREBRUM_AUTODIM_ON_MARK}"
      printf '%s\n' "$marked"
    else
      printf '%s\n' "$label"
    fi
  done
}

corebrum_autodim_refresh() {
  local dir name
  dir="$(corebrum_autodim_data_dir)/applications"
  name="$(corebrum_autodim_entry_name)"
  mkdir -p "$dir"
  cat >"${dir}/corebrum-autodim.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=${name}
GenericName=${name}
Comment=Choose when the display turns off
Exec=/usr/local/bin/corebrum-autodim open
Icon=display-brightness
Terminal=false
Categories=Settings;Display;
StartupNotify=false
EOF
}

corebrum_autodim_notify() {
  local summary="$1" body="$2"
  if [[ "${COREBRUM_AUTODIM_STUB:-0}" == 1 ]]; then
    return 0
  fi
  if ! command -v notify-send >/dev/null 2>&1; then
    return 0
  fi
  notify-send \
    --app-name=Corebrum \
    --urgency=low \
    --expire-time=3000 \
    --hint=string:x-canonical-private-synchronous:autodim \
    "$summary" \
    "$body" || true
}

corebrum_autodim_set_minutes() {
  local minutes="$1" dir label
  case "$minutes" in
    0 | 5 | 10 | 30 | 60) ;;
    *) corebrum_autodim_die "auto dim timer must be off or 5, 10, 30, or 60 minutes" ;;
  esac
  dir="$(corebrum_autodim_state_dir)"
  if [[ "${COREBRUM_AUTODIM_STUB:-0}" == 1 ]]; then
    mkdir -p "$dir"
    printf '%s\n' "$minutes" >"${dir}/autodim-minutes"
    printf 'minutes %s\n' "$minutes"
    return 0
  fi
  mkdir -p "$dir"
  printf '%s\n' "$minutes" >"${dir}/autodim-minutes"
  /usr/local/bin/corebrum-swayidle start
  label="$(corebrum_autodim_label "$minutes")"
  if [[ "$minutes" == 0 ]]; then
    corebrum_autodim_notify "Auto dim" "Auto dim is off."
  else
    corebrum_autodim_notify "Auto dim" "The display turns off after ${label} idle."
  fi
}

corebrum_autodim_terminal() {
  local script="$1"
  if [[ "${COREBRUM_AUTODIM_STUB:-0}" == 1 ]]; then
    printf '%s\n' "$script"
    return 0
  fi
  exec /usr/local/bin/corebrum-terminal bash -c "$script"
}

corebrum_autodim_apply_choice() {
  local choice="$1" minutes
  choice="${choice%"${COREBRUM_AUTODIM_ON_MARK}"}"
  case "$choice" in
    Off)
      minutes=0
      ;;
    "5 minutes" | "10 minutes" | "30 minutes" | "1 hour")
      case "$choice" in
        "1 hour") minutes=60 ;;
        *) minutes="${choice%% *}" ;;
      esac
      ;;
    *)
      corebrum_autodim_die "unknown auto dim choice"
      ;;
  esac
  corebrum_autodim_set_minutes "$minutes"
}

corebrum_autodim_swayidle_cmd() {
  local here
  if [[ -x /usr/local/bin/corebrum-swayidle ]]; then
    printf '%s\n' /usr/local/bin/corebrum-swayidle
    return 0
  fi
  here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  printf '%s\n' "${here}/corebrum-swayidle.sh"
}

corebrum_autodim_open() {
  local choice lines=5
  if ! corebrum_autodim_ready; then
    corebrum_autodim_terminal "$("$(corebrum_autodim_swayidle_cmd)" install-script)"
    return 0
  fi
  if [[ "${COREBRUM_AUTODIM_STUB:-0}" == 1 && -z "${COREBRUM_AUTODIM_CHOICE:-}" ]]; then
    corebrum_autodim_lines
    return 0
  fi
  if [[ "${COREBRUM_AUTODIM_STUB:-0}" == 1 ]]; then
    choice="$COREBRUM_AUTODIM_CHOICE"
    [[ -n "$choice" ]] || return 0
    corebrum_autodim_apply_choice "$choice"
    return 0
  fi
  choice="$(corebrum_autodim_lines | fuzzel \
    --config /etc/corebrum/fuzzel/fuzzel.ini \
    --dmenu \
    --prompt 'Auto dim  ' \
    --width 32 \
    --lines "$lines")" || return 0
  [[ -n "$choice" ]] || return 0
  corebrum_autodim_apply_choice "$choice"
}

usage() {
  cat <<'EOF'
Usage: corebrum-autodim refresh|open|set MINUTES|entry-name|data-dir|lines
EOF
}

cmd="${1:-}"
case "$cmd" in
  refresh) corebrum_autodim_refresh ;;
  open) corebrum_autodim_open ;;
  set) corebrum_autodim_set_minutes "${2:-}" ;;
  entry-name) corebrum_autodim_entry_name ;;
  data-dir) corebrum_autodim_data_dir ;;
  lines) corebrum_autodim_lines ;;
  -h | --help | help) usage ;;
  *)
    usage >&2
    exit 1
    ;;
esac
