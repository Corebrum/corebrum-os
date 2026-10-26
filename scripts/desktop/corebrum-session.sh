#!/usr/bin/env bash
# Start Hyprland with the Corebrum system config. greetd runs this after login.
set -euo pipefail

export XDG_CURRENT_DESKTOP=Hyprland
export XDG_SESSION_DESKTOP=Hyprland
export XDG_SESSION_TYPE=wayland

if [[ -f /etc/profile.d/corebrum-node.sh ]]; then
  # shellcheck disable=SC1091
  source /etc/profile.d/corebrum-node.sh || echo "corebrum-session: node profile failed" >&2
fi

if [[ -f /etc/profile.d/corebrum-ros.sh ]]; then
  # shellcheck disable=SC1091
  source /etc/profile.d/corebrum-ros.sh || echo "corebrum-session: ROS profile failed" >&2
fi

config="/etc/corebrum/hypr/hyprland.conf"
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
corebrum_export_vc4_devices
config="$(corebrum_hyprland_config "$config")"

# start-hyprland is the watchdog shipped with Hyprland. Starting the
# compositor directly leaves a warning on the desktop. Arguments after --
# are passed through, so the Corebrum config stays in use.
if command -v start-hyprland >/dev/null 2>&1; then
  exec start-hyprland -- --config "$config"
fi
if command -v Hyprland >/dev/null 2>&1; then
  exec Hyprland --config "$config"
fi
if command -v hyprland >/dev/null 2>&1; then
  exec hyprland --config "$config"
fi

echo "corebrum-session: Hyprland is not installed" >&2
exit 1
