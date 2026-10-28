#!/usr/bin/env bash
# Volume and brightness keys raise a Mako notification.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
osd="${ROOT}/scripts/desktop/corebrum-osd.sh"
conf="${ROOT}/config/sway/config"
mako="${ROOT}/config/mako/config"
fail=0

require_bind() {
  local needle="$1"
  if ! grep -qF -- "$needle" "$conf"; then
    echo "FAIL: sway config missing ${needle}" >&2
    fail=1
  fi
}

require_bind "bindsym XF86AudioRaiseVolume exec /usr/local/bin/corebrum-osd volume-up"
require_bind "bindsym XF86AudioLowerVolume exec /usr/local/bin/corebrum-osd volume-down"
require_bind "bindsym XF86AudioMute exec /usr/local/bin/corebrum-osd volume-mute"
require_bind "bindsym XF86AudioMicMute exec /usr/local/bin/corebrum-osd mic-mute"
require_bind "bindsym XF86MonBrightnessUp exec /usr/local/bin/corebrum-osd brightness-up"
require_bind "bindsym XF86MonBrightnessDown exec /usr/local/bin/corebrum-osd brightness-down"
if grep -q 'wpctl set-volume' "$conf"; then
  echo "FAIL: volume keys still change the level without a notification" >&2
  fail=1
fi
if ! grep -q 'libnotify-bin' "${ROOT}/manifests/packages/desktop.txt"; then
  echo "FAIL: the desktop profile does not install notify-send" >&2
  fail=1
fi
if ! grep -q 'layer=overlay' "$mako"; then
  echo "FAIL: notifications can sit under the bar or a fullscreen window" >&2
  fail=1
fi
if ! grep -q 'brightnessctl -c backlight' "$osd"; then
  echo "FAIL: brightness keys can change a keyboard LED" >&2
  fail=1
fi
if ! grep -q 'progress-color=over #3d9a8b' "$mako"; then
  echo "FAIL: volume notifications have no progress color" >&2
  fail=1
fi

output="$(COREBRUM_OSD_STUB=1 bash "$osd" volume-up)"
if [[ "$output" != "notify-send volume Volume 50% 50" ]]; then
  echo "FAIL: volume popup was ${output}" >&2
  fail=1
fi
output="$(COREBRUM_OSD_STUB=1 bash "$osd" brightness-down)"
if [[ "$output" != "notify-send brightness Brightness 40% 40" ]]; then
  echo "FAIL: brightness popup was ${output}" >&2
  fail=1
fi

if [[ "$fail" -ne 0 ]]; then
  exit 1
fi
echo "osd unit tests passed"
