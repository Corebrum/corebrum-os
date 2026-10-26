#!/usr/bin/env bash
# Start cage for gtkgreet. On a Raspberry Pi, card0 is the v3d render node and
# has no HDMI connector, so cage is pointed at the vc4 scanout device.
# x86_64 has no vc4 node, and cage keeps the same flags as before.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "${here}/corebrum-drm.sh" ]]; then
  # shellcheck source=corebrum-drm.sh
  source "${here}/corebrum-drm.sh"
elif [[ -f /usr/local/lib/corebrum/drm.sh ]]; then
  # shellcheck source=corebrum-drm.sh
  source /usr/local/lib/corebrum/drm.sh
else
  printf '%s\n' "corebrum-greetd: missing drm helper" >&2
  exit 1
fi

export XCURSOR_THEME=DMZ-White
export XCURSOR_SIZE=24
corebrum_export_vc4_devices
exec cage -s -d -- /usr/local/bin/corebrum-greeter
