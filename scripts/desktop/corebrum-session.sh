#!/usr/bin/env bash
# Start Hyprland with the Corebrum system config. greetd runs this after login.
set -euo pipefail

export XDG_CURRENT_DESKTOP=Hyprland
export XDG_SESSION_DESKTOP=Hyprland
export XDG_SESSION_TYPE=wayland

if [[ -f /etc/profile.d/corebrum-ros.sh ]]; then
  # shellcheck disable=SC1091
  source /etc/profile.d/corebrum-ros.sh || echo "corebrum-session: ROS profile failed" >&2
fi

config="/etc/corebrum/hypr/hyprland.conf"
if [[ ! -f "$config" ]]; then
  echo "corebrum-session: missing ${config}" >&2
  exit 1
fi

if command -v Hyprland >/dev/null 2>&1; then
  exec Hyprland --config "$config"
fi
if command -v hyprland >/dev/null 2>&1; then
  exec hyprland --config "$config"
fi

echo "corebrum-session: Hyprland is not installed" >&2
exit 1
