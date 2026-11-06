#!/usr/bin/env bash
# corebrum-battery-notify warns once when discharging at or below the threshold.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
script="${ROOT}/scripts/desktop/corebrum-battery-notify.sh"
sway_conf="${ROOT}/config/sway/config"
hypr_conf="${ROOT}/config/hypr/hyprland.conf"

if ! grep -qF 'exec /usr/local/bin/corebrum-battery-notify' "$sway_conf"; then
  echo "FAIL: Sway does not start corebrum-battery-notify" >&2
  exit 1
fi
if ! awk '/exec mako/{found=1} /exec \/usr\/local\/bin\/corebrum-battery-notify/{bat=1} END{exit !(found && bat)}' "$sway_conf"; then
  echo "FAIL: battery notifier should run after mako in Sway config" >&2
  exit 1
fi
if ! grep -qF 'exec-once = /usr/local/bin/corebrum-battery-notify' "$hypr_conf"; then
  echo "FAIL: Hyprland does not start corebrum-battery-notify" >&2
  exit 1
fi
if ! awk '/exec-once = mako --config/{found=1} /exec-once = \/usr\/local\/bin\/corebrum-battery-notify/{bat=1} END{exit !(found && bat)}' "$hypr_conf"; then
  echo "FAIL: battery notifier should run after mako in Hyprland config" >&2
  exit 1
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
bat="${tmp}/BAT0"
mkdir -p "$bat"
printf 'Battery\n' >"${bat}/type"
printf 'Discharging\n' >"${bat}/status"
printf '9\n' >"${bat}/capacity"
bin="${tmp}/bin"
mkdir -p "$bin"
log="${tmp}/notify.log"
cat >"${bin}/notify-send" <<EOF
#!/bin/sh
printf '%s\n' "\$*" >>"$log"
EOF
chmod +x "${bin}/notify-send"
export PATH="${bin}:${PATH}"
export COREBRUM_BATTERY_SYSFS="${tmp}"
export COREBRUM_BATTERY_NOTIFY_INTERVAL=1
export COREBRUM_BATTERY_NOTIFY_MAX_ITERATIONS=2
export XDG_STATE_HOME="${tmp}/state"
mkdir -p "$XDG_STATE_HOME/corebrum"

bash "$script" &
wait $!

if [[ ! -s "$log" ]]; then
  echo "FAIL: expected notify-send to run" >&2
  exit 1
fi
if ! grep -q 'Battery low' "$log"; then
  echo "FAIL: notification missing Battery low" >&2
  cat "$log" >&2
  exit 1
fi
if ! grep -q '9%' "$log"; then
  echo "FAIL: notification missing capacity" >&2
  cat "$log" >&2
  exit 1
fi
lines="$(wc -l <"$log")"
if [[ "$lines" -ne 1 ]]; then
  echo "FAIL: expected one notification, got ${lines}" >&2
  cat "$log" >&2
  exit 1
fi

# Second run: state file suppresses repeat at same low level.
: >"$log"
bash "$script" &
wait $!
if [[ -s "$log" ]]; then
  echo "FAIL: expected no second notification while still low" >&2
  cat "$log" >&2
  exit 1
fi

echo "ok: battery-notify"
