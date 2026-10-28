#!/usr/bin/env bash
# Start Sway with the Corebrum system config. greetd runs this after login.
set -euo pipefail

export XDG_CURRENT_DESKTOP=sway
export XDG_SESSION_DESKTOP=sway
export XDG_SESSION_TYPE=wayland

if [[ -f /etc/profile.d/corebrum-node.sh ]]; then
  # shellcheck disable=SC1091
  source /etc/profile.d/corebrum-node.sh || echo "corebrum-session: node profile failed" >&2
fi

if [[ -f /etc/profile.d/corebrum-ros.sh ]]; then
  # shellcheck disable=SC1091
  source /etc/profile.d/corebrum-ros.sh || echo "corebrum-session: ROS profile failed" >&2
fi

config="/etc/corebrum/sway/config"
if [[ ! -f "$config" ]]; then
  echo "corebrum-session: missing ${config}" >&2
  exit 1
fi

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "${here}/corebrum-drm.sh" ]]; then
  # shellcheck source=corebrum-drm.sh
  source "${here}/corebrum-drm.sh"
elif [[ -f /usr/local/lib/corebrum/drm.sh ]]; then
  # shellcheck source=corebrum-drm.sh
  source /usr/local/lib/corebrum/drm.sh
else
  echo "corebrum-session: missing drm helper" >&2
  exit 1
fi
# Sway reads WLR_DRM_DEVICES. On a Raspberry Pi that is the vc4 scanout device.
corebrum_export_vc4_devices

if ! command -v sway >/dev/null 2>&1; then
  echo "corebrum-session: sway is not installed" >&2
  exit 1
fi
exec sway --config "$config"
