#!/usr/bin/env bash
# Mako desktop notification when the main battery falls to a low charge while discharging.
# Exits quietly when there is no battery supply. Safe to run from Sway exec on every login.
set -euo pipefail

THRESHOLD="${COREBRUM_BATTERY_NOTIFY_THRESHOLD:-10}"
INTERVAL="${COREBRUM_BATTERY_NOTIFY_INTERVAL:-30}"
SYSROOT="${COREBRUM_BATTERY_SYSFS:-/sys/class/power_supply}"
MAX_ITER="${COREBRUM_BATTERY_NOTIFY_MAX_ITERATIONS:-}"

state_dir="${XDG_STATE_HOME:-${HOME}/.local/state}/corebrum"
mkdir -p "$state_dir"
state_file="${state_dir}/battery-notify-low"

wake_display() {
  local dim_cmd=""
  dim_cmd="$(command -v corebrum-display-dim 2>/dev/null || true)"
  if [[ -z "$dim_cmd" && -x /usr/local/bin/corebrum-display-dim ]]; then
    dim_cmd=/usr/local/bin/corebrum-display-dim
  fi
  if [[ -n "$dim_cmd" ]]; then
    "$dim_cmd" on || true
  elif command -v swaymsg >/dev/null 2>&1; then
    swaymsg output '*' dpms on >/dev/null 2>&1 || true
  fi
}

notify_low() {
  local cap="$1"
  wake_display
  if ! command -v notify-send >/dev/null 2>&1; then
    return 0
  fi
  notify-send --app-name=Corebrum --urgency=critical \
    "Battery low" "About ${cap}% remaining. Plug in power." || true
}

read_capacity() {
  local base="$1" cap now full
  if [[ -r "${base}/capacity" ]]; then
    read -r cap <"${base}/capacity" || return 1
    printf '%s\n' "${cap%%.*}"
    return 0
  fi
  if [[ -r "${base}/charge_now" && -r "${base}/charge_full" ]]; then
    read -r now <"${base}/charge_now"
    read -r full <"${base}/charge_full"
  elif [[ -r "${base}/energy_now" && -r "${base}/energy_full" ]]; then
    read -r now <"${base}/energy_now"
    read -r full <"${base}/energy_full"
  else
    return 1
  fi
  [[ -n "$full" && "$full" -gt 0 ]] || return 1
  cap=$((100 * now / full))
  if [[ "$cap" -lt 0 ]]; then
    cap=0
  elif [[ "$cap" -gt 100 ]]; then
    cap=100
  fi
  printf '%s\n' "$cap"
}

primary_battery() {
  local f t
  for f in "${SYSROOT}"/*/type; do
    [[ -e "$f" ]] || continue
    read -r t <"$f" || continue
    if [[ "$t" == "Battery" ]]; then
      printf '%s\n' "${f%/type}"
      return 0
    fi
  done
  return 1
}

is_discharging() {
  local base="$1" s
  [[ -r "${base}/status" ]] || return 1
  read -r s <"${base}/status"
  case "$s" in
    Discharging) return 0 ;;
    *) return 1 ;;
  esac
}

iteration=0
while true; do
  if [[ -n "$MAX_ITER" ]]; then
    iteration=$((iteration + 1))
    if [[ "$iteration" -gt "$MAX_ITER" ]]; then
      break
    fi
  fi

  bat=""
  bat="$(primary_battery)" || true

  if [[ -z "$bat" ]]; then
    rm -f "$state_file"
    sleep "$INTERVAL"
    continue
  fi

  cap=""
  cap="$(read_capacity "$bat")" || cap=""

  if [[ -z "$cap" ]]; then
    sleep "$INTERVAL"
    continue
  fi

  if is_discharging "$bat"; then
    if [[ "$cap" -le "$THRESHOLD" ]]; then
      if [[ ! -f "$state_file" ]]; then
        notify_low "$cap"
        : >"$state_file"
      fi
    else
      rm -f "$state_file"
    fi
  else
    rm -f "$state_file"
  fi

  sleep "$INTERVAL"
done
