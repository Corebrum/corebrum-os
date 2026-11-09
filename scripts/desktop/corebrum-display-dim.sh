#!/usr/bin/env bash
# Turn the panel off for idle power saving, or restore it on input or low battery.
set -euo pipefail

COREBRUM_DISPLAY_DIM_STATE="${XDG_STATE_HOME:-${HOME}/.local/state}/corebrum"
BRIGHTNESS_SAVED="${COREBRUM_DISPLAY_DIM_STATE}/display-brightness-saved"
DIMMED_MARK="${COREBRUM_DISPLAY_DIM_STATE}/display-dimmed"

corebrum_display_dim_save_brightness() {
  local line pct
  if ! command -v brightnessctl >/dev/null 2>&1; then
    return 0
  fi
  line="$(brightnessctl -c backlight --machine-readable 2>/dev/null || true)"
  pct="$(awk -F, '{
    for (i = 1; i <= NF; i++) if ($i ~ /%$/) { gsub("%", "", $i); print $i; exit }
  }' <<<"$line")"
  [[ -n "$pct" ]] || return 0
  mkdir -p "$COREBRUM_DISPLAY_DIM_STATE"
  printf '%s\n' "$pct" >"$BRIGHTNESS_SAVED"
}

corebrum_display_dim_off() {
  if [[ "${COREBRUM_DISPLAY_DIM_STUB:-0}" == 1 ]]; then
    printf 'dim off\n'
    return 0
  fi
  if [[ -f "$DIMMED_MARK" ]]; then
    return 0
  fi
  corebrum_display_dim_save_brightness
  mkdir -p "$COREBRUM_DISPLAY_DIM_STATE"
  touch "$DIMMED_MARK"
  if command -v swaymsg >/dev/null 2>&1; then
    swaymsg output '*' dpms off >/dev/null 2>&1 || true
  fi
  if command -v brightnessctl >/dev/null 2>&1; then
    brightnessctl -c backlight set 0 >/dev/null 2>&1 || true
  fi
}

corebrum_display_dim_on() {
  local pct
  if [[ "${COREBRUM_DISPLAY_DIM_STUB:-0}" == 1 ]]; then
    printf 'dim on\n'
    return 0
  fi
  if command -v swaymsg >/dev/null 2>&1; then
    swaymsg output '*' dpms on >/dev/null 2>&1 || true
  fi
  if command -v brightnessctl >/dev/null 2>&1; then
    if [[ -f "$BRIGHTNESS_SAVED" ]]; then
      read -r pct <"$BRIGHTNESS_SAVED" || pct=""
      if [[ -n "$pct" && "$pct" =~ ^[0-9]+$ ]]; then
        brightnessctl -c backlight set "${pct}%" >/dev/null 2>&1 || true
      else
        brightnessctl -c backlight set 100% >/dev/null 2>&1 || true
      fi
    else
      brightnessctl -c backlight set 100% >/dev/null 2>&1 || true
    fi
  fi
  rm -f "$DIMMED_MARK"
}

usage() {
  cat <<'EOF'
Usage: corebrum-display-dim off|on
EOF
}

cmd="${1:-}"
case "$cmd" in
  off) corebrum_display_dim_off ;;
  on) corebrum_display_dim_on ;;
  -h | --help | help) usage ;;
  *)
    usage >&2
    exit 1
    ;;
esac
