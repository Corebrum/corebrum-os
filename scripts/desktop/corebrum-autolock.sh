#!/usr/bin/env bash
# Super+Space autolock timer, and a stay-awake pause for this session.
set -euo pipefail

COREBRUM_AUTOLOCK_INSTALL_MARK='   install'
COREBRUM_AUTOLOCK_ON_MARK='   on'
COREBRUM_AUTOLOCK_SYSTEM_CONFIG=/etc/corebrum/sway/idle.conf

corebrum_autolock_die() {
  printf 'corebrum-autolock: %s\n' "$1" >&2
  exit 1
}

corebrum_autolock_state_dir() {
  local root="${XDG_STATE_HOME:-${HOME}/.local/state}"
  printf '%s\n' "${root}/corebrum"
}

corebrum_autolock_runtime_dir() {
  local root="${XDG_RUNTIME_DIR:-/tmp/corebrum-autolock-${UID}}"
  printf '%s\n' "${root}/corebrum"
}

corebrum_autolock_data_dir() {
  corebrum_autolock_runtime_dir
}

corebrum_autolock_pidfile() {
  printf '%s\n' "$(corebrum_autolock_runtime_dir)/stay-awake.pid"
}

corebrum_autolock_ready() {
  if [[ "${COREBRUM_AUTOLOCK_STUB:-0}" == 1 ]]; then
    [[ "${COREBRUM_AUTOLOCK_READY:-0}" == 1 ]]
    return
  fi
  command -v swayidle >/dev/null 2>&1
}

corebrum_autolock_minutes() {
  local file minutes
  if [[ -n "${COREBRUM_AUTOLOCK_MINUTES:-}" ]]; then
    minutes="$COREBRUM_AUTOLOCK_MINUTES"
  else
    file="$(corebrum_autolock_state_dir)/autolock-minutes"
    if [[ -f "$file" ]]; then
      minutes="$(tr -d '[:space:]' <"$file")"
    else
      minutes=10
    fi
  fi
  case "$minutes" in
    5 | 10 | 30 | 60) printf '%s\n' "$minutes" ;;
    *) printf '10\n' ;;
  esac
}

corebrum_autolock_label() {
  local minutes="$1"
  if [[ "$minutes" == 60 ]]; then
    printf '1 hour\n'
  else
    printf '%s minutes\n' "$minutes"
  fi
}

corebrum_autolock_awake() {
  local pidfile pid
  if [[ "${COREBRUM_AUTOLOCK_STUB:-0}" == 1 ]]; then
    [[ "${COREBRUM_AUTOLOCK_AWAKE:-0}" == 1 ]]
    return
  fi
  pidfile="$(corebrum_autolock_pidfile)"
  [[ -f "$pidfile" ]] || return 1
  pid="$(tr -d '[:space:]' <"$pidfile")"
  [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null
}

corebrum_autolock_entry_name() {
  if corebrum_autolock_ready; then
    printf 'Autolock\n'
  else
    printf 'Autolock%s\n' "$COREBRUM_AUTOLOCK_INSTALL_MARK"
  fi
}

corebrum_autolock_lines() {
  local minutes current label marked
  minutes="$(corebrum_autolock_minutes)"
  if corebrum_autolock_awake; then
    printf 'Stay awake%s\n' "$COREBRUM_AUTOLOCK_ON_MARK"
  else
    printf 'Stay awake\n'
  fi
  for current in 5 10 30 60; do
    label="$(corebrum_autolock_label "$current")"
    if [[ "$current" == "$minutes" ]]; then
      marked="${label}${COREBRUM_AUTOLOCK_ON_MARK}"
      printf '%s\n' "$marked"
    else
      printf '%s\n' "$label"
    fi
  done
}

corebrum_autolock_refresh() {
  local dir name
  dir="$(corebrum_autolock_data_dir)/applications"
  name="$(corebrum_autolock_entry_name)"
  mkdir -p "$dir"
  cat >"${dir}/corebrum-autolock.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=${name}
GenericName=${name}
Comment=Choose when the screen locks
Exec=/usr/local/bin/corebrum-autolock open
Icon=system-lock-screen
Terminal=false
Categories=Settings;DesktopSettings;
StartupNotify=false
EOF
}

corebrum_autolock_render() {
  local minutes="$1" seconds
  case "$minutes" in
    5 | 10 | 30 | 60) ;;
    *) corebrum_autolock_die "autolock timer must be 5, 10, 30, or 60 minutes" ;;
  esac
  seconds=$((minutes * 60))
  printf 'timeout=%s\n' "$seconds"
}

corebrum_autolock_config_path() {
  local minutes_file
  minutes_file="$(corebrum_autolock_state_dir)/autolock-minutes"
  if [[ -f "$minutes_file" ]]; then
    printf '%s\n' "$(corebrum_autolock_state_dir)/idle.conf"
  else
    printf '%s\n' "$COREBRUM_AUTOLOCK_SYSTEM_CONFIG"
  fi
}

corebrum_autolock_notify() {
  local summary="$1" body="$2"
  if [[ "${COREBRUM_AUTOLOCK_STUB:-0}" == 1 ]]; then
    return 0
  fi
  if ! command -v notify-send >/dev/null 2>&1; then
    return 0
  fi
  notify-send \
    --app-name=Corebrum \
    --urgency=low \
    --expire-time=3000 \
    --hint=string:x-canonical-private-synchronous:autolock \
    "$summary" \
    "$body" || true
}

corebrum_autolock_start() {
  local cfg
  if [[ "${COREBRUM_AUTOLOCK_STUB:-0}" == 1 ]]; then
    corebrum_autolock_config_path
    return 0
  fi
  command -v swayidle >/dev/null 2>&1 || return 0
  cfg="$(corebrum_autolock_config_path)"
  [[ -f "$cfg" ]] || return 0
  seconds="$(sed -n 's/^timeout=//p' "$cfg" | head -n 1)"
  case "$seconds" in
    '' | *[!0-9]*) return 0 ;;
  esac
  if pgrep -x swayidle >/dev/null 2>&1; then
    pkill -x swayidle || true
    local _
    for _ in 1 2 3 4 5 6 7 8 9 10; do
      pgrep -x swayidle >/dev/null 2>&1 || break
      sleep 0.1
    done
  fi
  # swayidle honors a systemd idle inhibitor, so Stay awake pauses the timer.
  setsid --fork -- swayidle -w \
    timeout "$seconds" /usr/local/bin/corebrum-lock \
    before-sleep 'loginctl lock-session' </dev/null >/dev/null 2>&1
}

corebrum_autolock_set_minutes() {
  local minutes="$1" dir cfg label
  dir="$(corebrum_autolock_state_dir)"
  cfg="${dir}/idle.conf"
  if [[ "${COREBRUM_AUTOLOCK_STUB:-0}" == 1 ]]; then
    mkdir -p "$dir"
    printf '%s\n' "$minutes" >"${dir}/autolock-minutes"
    corebrum_autolock_render "$minutes" >"$cfg"
    printf 'minutes %s\n' "$minutes"
    return 0
  fi
  mkdir -p "$dir"
  printf '%s\n' "$minutes" >"${dir}/autolock-minutes"
  corebrum_autolock_render "$minutes" >"${cfg}.tmp"
  mv "${cfg}.tmp" "$cfg"
  corebrum_autolock_stay_awake_stop
  corebrum_autolock_start
  label="$(corebrum_autolock_label "$minutes")"
  corebrum_autolock_notify "Autolock" "The screen locks after ${label} idle."
}

corebrum_autolock_stay_awake_stop() {
  local pidfile pid
  if [[ "${COREBRUM_AUTOLOCK_STUB:-0}" == 1 ]]; then
    return 0
  fi
  pidfile="$(corebrum_autolock_pidfile)"
  if [[ -f "$pidfile" ]]; then
    pid="$(tr -d '[:space:]' <"$pidfile")"
    if [[ -n "$pid" ]]; then
      kill "$pid" 2>/dev/null || true
    fi
    rm -f "$pidfile"
  fi
}

corebrum_autolock_stay_awake_start() {
  local pidfile
  if [[ "${COREBRUM_AUTOLOCK_STUB:-0}" == 1 ]]; then
    return 0
  fi
  if corebrum_autolock_awake; then
    return 0
  fi
  pidfile="$(corebrum_autolock_pidfile)"
  mkdir -p "$(dirname "$pidfile")"
  setsid systemd-inhibit --what=idle --who=Corebrum --why="Stay awake" --mode=block sleep infinity </dev/null >/dev/null 2>&1 &
  printf '%s\n' "$!" >"$pidfile"
}

corebrum_autolock_toggle() {
  local label
  if corebrum_autolock_awake; then
    corebrum_autolock_stay_awake_stop
    if [[ "${COREBRUM_AUTOLOCK_STUB:-0}" == 1 ]]; then
      printf 'awake off\n'
      return 0
    fi
    label="$(corebrum_autolock_label "$(corebrum_autolock_minutes)")"
    corebrum_autolock_notify "Autolock" "The screen locks after ${label} idle."
    return 0
  fi
  corebrum_autolock_stay_awake_start
  if [[ "${COREBRUM_AUTOLOCK_STUB:-0}" == 1 ]]; then
    printf 'awake on\n'
    return 0
  fi
  corebrum_autolock_notify "Stay awake" "The screen will not lock by itself."
}

corebrum_autolock_install_script() {
  cat <<'EOF'
set +e
candidate=$(apt-cache policy swayidle | awk '/Candidate:/ { print $2; exit }')
locker=$(apt-cache policy gtklock | awk '/Candidate:/ { print $2; exit }')
if [ -z "$candidate" ] || [ "$candidate" = "(none)" ] || [ -z "$locker" ] || [ "$locker" = "(none)" ]; then
  printf '%s\n' "swayidle and gtklock are not both in this Ubuntu archive."
  printf '\n'
  read -r -p 'Press Enter to close. '
  exit 0
fi
sudo apt-get update && sudo apt-get install -y swayidle gtklock
ec=$?
if [ "$ec" -eq 0 ]; then
  /usr/local/bin/corebrum-autolock start
  ec=$?
fi
set -e
printf '\n'
if [ "$ec" -eq 0 ]; then
  printf '%s\n' "Autolock is installed. The screen locks after 10 minutes idle."
else
  printf 'Install failed (%s).\n' "$ec"
fi
read -r -p 'Press Enter to close. '
EOF
}

corebrum_autolock_terminal() {
  local script="$1"
  if [[ "${COREBRUM_AUTOLOCK_STUB:-0}" == 1 ]]; then
    printf '%s\n' "$script"
    return 0
  fi
  exec /usr/local/bin/corebrum-terminal bash -c "$script"
}

corebrum_autolock_apply_choice() {
  local choice="$1" minutes label
  choice="${choice%"${COREBRUM_AUTOLOCK_ON_MARK}"}"
  case "$choice" in
    "Stay awake")
      corebrum_autolock_toggle
      ;;
    "5 minutes" | "10 minutes" | "30 minutes" | "1 hour")
      case "$choice" in
        "1 hour") minutes=60 ;;
        *) minutes="${choice%% *}" ;;
      esac
      corebrum_autolock_set_minutes "$minutes"
      ;;
    *)
      corebrum_autolock_die "unknown autolock choice"
      ;;
  esac
}

corebrum_autolock_open() {
  local choice lines=5
  if ! corebrum_autolock_ready; then
    corebrum_autolock_terminal "$(corebrum_autolock_install_script)"
    return 0
  fi
  if [[ "${COREBRUM_AUTOLOCK_STUB:-0}" == 1 && -z "${COREBRUM_AUTOLOCK_CHOICE:-}" ]]; then
    corebrum_autolock_lines
    return 0
  fi
  if [[ "${COREBRUM_AUTOLOCK_STUB:-0}" == 1 ]]; then
    choice="$COREBRUM_AUTOLOCK_CHOICE"
  else
    choice="$(corebrum_autolock_lines | fuzzel \
      --config /etc/corebrum/fuzzel/fuzzel.ini \
      --dmenu \
      --prompt 'Autolock  ' \
      --width 32 \
      --lines "$lines")" || return 0
  fi
  [[ -n "$choice" ]] || return 0
  corebrum_autolock_apply_choice "$choice"
}

usage() {
  cat <<'EOF'
Usage: corebrum-autolock refresh|open|toggle|start|render MINUTES|entry-name|data-dir|lines
EOF
}

cmd="${1:-}"
case "$cmd" in
  refresh) corebrum_autolock_refresh ;;
  open) corebrum_autolock_open ;;
  toggle) corebrum_autolock_toggle ;;
  start) corebrum_autolock_start ;;
  hold)
    # Kept so a stay-awake process can be identified. The inhibitor runs sleep.
    exec sleep infinity
    ;;
  render) corebrum_autolock_render "${2:-}" ;;
  entry-name) corebrum_autolock_entry_name ;;
  data-dir) corebrum_autolock_data_dir ;;
  lines) corebrum_autolock_lines ;;
  -h | --help | help) usage ;;
  *)
    usage >&2
    exit 1
    ;;
esac
