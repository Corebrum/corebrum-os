#!/usr/bin/env bash
# One swayidle process for autolock and optional autodim.
set -euo pipefail

COREBRUM_SWAYIDLE_SYSTEM_AUTOLOCK=/etc/corebrum/sway/idle.conf
LOCK_CMD="/usr/local/bin/corebrum-lock idle"
DIM_OFF_CMD=/usr/local/bin/corebrum-display-dim
DIM_ON_CMD=/usr/local/bin/corebrum-display-dim

corebrum_swayidle_die() {
  printf 'corebrum-swayidle: %s\n' "$1" >&2
  exit 1
}

corebrum_swayidle_state_dir() {
  local root="${XDG_STATE_HOME:-${HOME}/.local/state}"
  printf '%s\n' "${root}/corebrum"
}

corebrum_swayidle_ready() {
  command -v swayidle >/dev/null 2>&1
}

corebrum_swayidle_autolock_config() {
  local minutes_file
  minutes_file="$(corebrum_swayidle_state_dir)/autolock-minutes"
  if [[ -f "$minutes_file" ]]; then
    printf '%s\n' "$(corebrum_swayidle_state_dir)/idle.conf"
  else
    printf '%s\n' "$COREBRUM_SWAYIDLE_SYSTEM_AUTOLOCK"
  fi
}

corebrum_swayidle_autolock_seconds() {
  local cfg seconds
  cfg="$(corebrum_swayidle_autolock_config)"
  [[ -f "$cfg" ]] || return 1
  seconds="$(sed -n 's/^timeout=//p' "$cfg" | head -n 1)"
  case "$seconds" in
    '' | *[!0-9]*) return 1 ;;
  esac
  printf '%s\n' "$seconds"
}

corebrum_swayidle_autodim_seconds() {
  local file minutes
  file="$(corebrum_swayidle_state_dir)/autodim-minutes"
  [[ -f "$file" ]] || return 1
  minutes="$(tr -d '[:space:]' <"$file")"
  [[ "$minutes" == 0 ]] && return 1
  case "$minutes" in
    5 | 10 | 30 | 60) printf '%s\n' "$((minutes * 60))" ;;
    *) return 1 ;;
  esac
}

corebrum_swayidle_stop() {
  if [[ "${COREBRUM_SWAYIDLE_STUB:-0}" == 1 ]]; then
    return 0
  fi
  if ! pgrep -x swayidle >/dev/null 2>&1; then
    return 0
  fi
  pkill -x swayidle || true
  local _
  for _ in 1 2 3 4 5 6 7 8 9 10; do
    pgrep -x swayidle >/dev/null 2>&1 || break
    sleep 0.1
  done
}

corebrum_swayidle_start() {
  local lock_sec dim_sec dim_on dim_off
  local -a args=()

  if [[ "${COREBRUM_SWAYIDLE_STUB:-0}" == 1 ]]; then
    return 0
  fi
  corebrum_swayidle_ready || return 0
  lock_sec="$(corebrum_swayidle_autolock_seconds)" || return 0
  dim_sec=""
  dim_sec="$(corebrum_swayidle_autodim_seconds)" || true
  dim_off="${DIM_OFF_CMD} off"
  dim_on="${DIM_ON_CMD} on"

  args=(-w)
  if [[ -n "$dim_sec" ]]; then
    # swayidle runs each idle_cmd in sh -c; resume must sit on the same timeout line.
    if [[ "$dim_sec" -le "$lock_sec" ]]; then
      args+=(timeout "$dim_sec" "$dim_off" resume "$dim_on")
      args+=(timeout "$lock_sec" "$LOCK_CMD" resume "$dim_on")
    else
      args+=(timeout "$lock_sec" "$LOCK_CMD" resume "$dim_on")
      args+=(timeout "$dim_sec" "$dim_off" resume "$dim_on")
    fi
  else
    args+=(timeout "$lock_sec" "$LOCK_CMD")
  fi
  args+=(before-sleep 'loginctl lock-session')

  corebrum_swayidle_stop
  # swayidle honors a systemd idle inhibitor, so Stay awake pauses the timer.
  setsid --fork -- swayidle "${args[@]}" </dev/null >/dev/null 2>&1
}

corebrum_swayidle_install_script() {
  cat <<'EOF'
set +e
codename=$(. /etc/os-release && printf '%s' "${VERSION_CODENAME:-}")
candidate=$(apt-cache policy swayidle | awk '/Candidate:/ { print $2; exit }')
if [ -z "$candidate" ] || [ "$candidate" = "(none)" ]; then
  printf '%s\n' "swayidle is not in this Ubuntu archive."
  printf '\n'
  read -r -p 'Press Enter to close. '
  exit 0
fi
if [ "$codename" = "noble" ]; then
  sudo apt-get update && sudo apt-get install -y swayidle
  ec=$?
  if [ "$ec" -eq 0 ] && ! /usr/local/bin/gtklock -v 2>/dev/null | grep -q '^gtklock v4\.'; then
    printf '%s\n' "The lock screen is gtklock 4. Run: sudo corebrum install desktop"
    ec=1
  fi
else
  locker=$(apt-cache policy gtklock | awk '/Candidate:/ { print $2; exit }')
  if [ -z "$locker" ] || [ "$locker" = "(none)" ]; then
    printf '%s\n' "gtklock is not in this Ubuntu archive."
    printf '\n'
    read -r -p 'Press Enter to close. '
    exit 0
  fi
  sudo apt-get update && sudo apt-get install -y swayidle gtklock
  ec=$?
fi
if [ "$ec" -eq 0 ]; then
  /usr/local/bin/corebrum-swayidle start
  ec=$?
fi
set -e
printf '\n'
if [ "$ec" -eq 0 ]; then
  printf '%s\n' "swayidle is installed. Autolock still applies. Auto dim follows Setup."
else
  printf 'Install failed (%s).\n' "$ec"
fi
read -r -p 'Press Enter to close. '
EOF
}

usage() {
  cat <<'EOF'
Usage: corebrum-swayidle start|install-script
EOF
}

cmd="${1:-}"
case "$cmd" in
  start) corebrum_swayidle_start ;;
  install-script) corebrum_swayidle_install_script ;;
  -h | --help | help) usage ;;
  *)
    usage >&2
    exit 1
    ;;
esac
