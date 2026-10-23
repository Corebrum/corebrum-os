#!/usr/bin/env bash
# Volume and brightness keys. Mako draws the popup.
set -euo pipefail

corebrum_osd_notify() {
  local tag="$1" summary="$2" body="$3" value="${4:-}"
  local -a hints=(-h "string:x-canonical-private-synchronous:${tag}")
  if [[ -n "$value" ]]; then
    hints+=(-h "int:value:${value}")
  fi
  if [[ "${COREBRUM_OSD_STUB:-0}" == 1 ]]; then
    printf 'notify-send %s %s %s %s\n' "$tag" "$summary" "$body" "${value:-}"
    return 0
  fi
  if ! command -v notify-send >/dev/null 2>&1; then
    return 0
  fi
  notify-send \
    --app-name=Corebrum \
    --urgency=low \
    --expire-time=2000 \
    "${hints[@]}" \
    "$summary" \
    "$body"
}

corebrum_osd_volume_popup() {
  local line raw pct
  line="$(wpctl get-volume @DEFAULT_AUDIO_SINK@)"
  raw="${line#Volume: }"
  raw="${raw%% *}"
  pct="$(awk -v v="$raw" 'BEGIN { printf "%d", (v * 100) + 0.5 }')"
  if [[ "$line" == *"[MUTED]"* ]]; then
    corebrum_osd_notify volume Volume Muted 0
  else
    corebrum_osd_notify volume Volume "${pct}%" "$pct"
  fi
}

corebrum_osd_mic_popup() {
  local line
  line="$(wpctl get-volume @DEFAULT_AUDIO_SOURCE@)"
  if [[ "$line" == *"[MUTED]"* ]]; then
    corebrum_osd_notify microphone Microphone Muted 0
  else
    corebrum_osd_notify microphone Microphone On 100
  fi
}

corebrum_osd_brightness_popup() {
  local line pct
  line="$(brightnessctl -c backlight --machine-readable 2>/dev/null || true)"
  pct="$(awk -F, '{
    for (i = 1; i <= NF; i++) if ($i ~ /%$/) { gsub("%", "", $i); print $i; exit }
  }' <<<"$line")"
  if [[ -z "$pct" ]]; then
    corebrum_osd_notify brightness Brightness "No display brightness control"
    return 0
  fi
  corebrum_osd_notify brightness Brightness "${pct}%" "$pct"
}

usage() {
  cat <<'EOF'
Usage: corebrum-osd volume-up|volume-down|volume-mute|mic-mute|brightness-up|brightness-down
EOF
}

cmd="${1:-}"
if [[ "${COREBRUM_OSD_STUB:-0}" == 1 ]]; then
  case "$cmd" in
    volume-up | volume-down | volume-mute)
      corebrum_osd_notify volume Volume "50%" 50
      exit 0
      ;;
    mic-mute)
      corebrum_osd_notify microphone Microphone Muted 0
      exit 0
      ;;
    brightness-up | brightness-down)
      corebrum_osd_notify brightness Brightness "40%" 40
      exit 0
      ;;
    -h | --help | help)
      usage
      exit 0
      ;;
    *)
      usage >&2
      exit 1
      ;;
  esac
fi

case "$cmd" in
  volume-up)
    wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+
    corebrum_osd_volume_popup
    ;;
  volume-down)
    wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-
    corebrum_osd_volume_popup
    ;;
  volume-mute)
    wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
    corebrum_osd_volume_popup
    ;;
  mic-mute)
    wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle
    corebrum_osd_mic_popup
    ;;
  brightness-up)
    brightnessctl -c backlight -e4 -n2 set 5%+ >/dev/null 2>&1 || true
    corebrum_osd_brightness_popup
    ;;
  brightness-down)
    brightnessctl -c backlight -e4 -n2 set 5%- >/dev/null 2>&1 || true
    corebrum_osd_brightness_popup
    ;;
  -h | --help | help) usage ;;
  *)
    usage >&2
    exit 1
    ;;
esac
