#!/usr/bin/env bash
# Start Sway for wlgreet. wlgreet is a layer-shell client. Ubuntu cage 0.2.1
# does not advertise zwlr_layer_shell_v1, so wlgreet exits at once and greetd
# hits its start limit. On a Raspberry Pi, card0 is the v3d render node and
# has no HDMI connector, so Sway is pointed at the vc4 scanout device.
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
if corebrum_prepare_nvidia_sway; then
  printf '%s\n' "corebrum-greetd: proprietary NVIDIA driver; starting Sway with --unsupported-gpu" >&2
  exec sway --unsupported-gpu --config /etc/corebrum/greetd/sway-config
fi
exec sway --config /etc/corebrum/greetd/sway-config
