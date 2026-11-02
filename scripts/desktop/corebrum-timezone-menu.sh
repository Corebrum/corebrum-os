#!/usr/bin/env bash
# Super+Space Setup → Timezone. Pick a zone with Fuzzel; apply with timedatectl.
set -euo pipefail

corebrum_timezone_die() {
  printf 'corebrum-timezone-menu: %s\n' "$1" >&2
  exit 1
}

corebrum_timezone_data_dir() {
  local root="${XDG_RUNTIME_DIR:-/tmp/corebrum-launcher-${UID}}"
  printf '%s\n' "${root}/corebrum"
}

corebrum_timezone_current() {
  if [[ -n "${COREBRUM_TIMEZONE_CURRENT:-}" ]]; then
    printf '%s\n' "$COREBRUM_TIMEZONE_CURRENT"
    return 0
  fi
  if ! command -v timedatectl >/dev/null 2>&1; then
    printf '\n'
    return 0
  fi
  timedatectl show -p Timezone --value 2>/dev/null || printf '\n'
}

corebrum_timezone_entry_name() {
  local zone
  zone="$(corebrum_timezone_current)"
  if [[ -n "$zone" ]]; then
    printf 'Timezone   %s\n' "$zone"
  else
    printf 'Timezone\n'
  fi
}

corebrum_timezone_lines() {
  local current zone
  current="$(corebrum_timezone_current)"
  if [[ -n "${COREBRUM_TIMEZONE_LINES:-}" ]]; then
    if [[ -n "$current" ]]; then
      printf '%s\n' "$current"
    fi
    while IFS= read -r zone; do
      [[ -z "$zone" || "$zone" == "$current" ]] && continue
      printf '%s\n' "$zone"
    done <<<"$COREBRUM_TIMEZONE_LINES"
    return 0
  fi
  if [[ -n "$current" ]]; then
    printf '%s\n' "$current"
  fi
  while IFS= read -r zone; do
    [[ -z "$zone" || "$zone" == "$current" ]] && continue
    printf '%s\n' "$zone"
  done < <(timedatectl list-timezones 2>/dev/null || true)
}

corebrum_timezone_refresh() {
  local dir name
  dir="$(corebrum_timezone_data_dir)/applications"
  name="$(corebrum_timezone_entry_name)"
  mkdir -p "$dir"
  cat >"${dir}/corebrum-timezone.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=${name}
GenericName=Timezone
Comment=Set the system time zone
Keywords=timezone;tz;time zone;clock;timedatectl;
Exec=/usr/local/bin/corebrum-timezone-menu open
Icon=preferences-system-time
Terminal=false
Categories=Settings;System;
StartupNotify=false
EOF
}

corebrum_timezone_notify() {
  local zone="$1"
  if command -v notify-send >/dev/null 2>&1; then
    notify-send --app-name=Corebrum Timezone "$zone" || true
  else
    printf 'corebrum-timezone-menu: timezone set to %s\n' "$zone" >&2
  fi
}

corebrum_timezone_apply() {
  local zone="$1"
  [[ -n "$zone" ]] || return 0
  if [[ "${COREBRUM_TIMEZONE_STUB:-0}" == 1 ]]; then
    printf 'timedatectl set-timezone %s\n' "$zone"
    return 0
  fi
  if command -v pkexec >/dev/null 2>&1; then
    pkexec timedatectl set-timezone "$zone" || corebrum_timezone_die "could not set timezone ${zone}"
  else
    exec /usr/local/bin/corebrum-terminal bash -c "
set +e
sudo timedatectl set-timezone $(printf '%q' "$zone")
ec=\$?
set -e
printf '\\n'
if [ \"\$ec\" -eq 0 ]; then
  printf 'Timezone set to %s.\\n' $(printf '%q' "$zone")
else
  printf 'Could not set timezone (%s).\\n' \"\$ec\"
fi
read -r -p 'Press Enter to close. '
exit \"\$ec\"
"
  fi
  corebrum_timezone_notify "$zone"
}

corebrum_timezone_open() {
  local choice
  if [[ "${COREBRUM_TIMEZONE_STUB:-0}" == 1 && -z "${COREBRUM_TIMEZONE_CHOICE:-}" ]]; then
    corebrum_timezone_lines
    return 0
  fi
  if [[ "${COREBRUM_TIMEZONE_STUB:-0}" == 1 ]]; then
    choice="${COREBRUM_TIMEZONE_CHOICE:-}"
    [[ -n "$choice" ]] || return 0
    corebrum_timezone_apply "$choice"
    return 0
  fi
  choice="$(corebrum_timezone_lines | fuzzel \
    --config /etc/corebrum/fuzzel/fuzzel.ini \
    --dmenu \
    --prompt 'Timezone  ' \
    --width 48 \
    --lines 12)" || return 0
  [[ -n "$choice" ]] || return 0
  corebrum_timezone_apply "$choice"
}

usage() {
  cat <<'EOF'
Usage: corebrum-timezone-menu refresh|open|entry-name|data-dir|lines|current
EOF
}

cmd="${1:-}"
case "$cmd" in
  refresh) corebrum_timezone_refresh ;;
  open) corebrum_timezone_open ;;
  entry-name) corebrum_timezone_entry_name ;;
  data-dir) corebrum_timezone_data_dir ;;
  lines) corebrum_timezone_lines ;;
  current) corebrum_timezone_current ;;
  -h | --help | help) usage ;;
  *)
    usage >&2
    exit 1
    ;;
esac
