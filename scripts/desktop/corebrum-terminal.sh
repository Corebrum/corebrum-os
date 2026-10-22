#!/usr/bin/env bash
# Kitty with the Corebrum system config. Hyprland binds this command.
# A new terminal is not a login shell, so source the ROS profile here.
set -euo pipefail
if [[ -f /etc/profile.d/corebrum-ros.sh ]]; then
  # shellcheck disable=SC1091
  source /etc/profile.d/corebrum-ros.sh || echo "corebrum-terminal: ROS profile failed" >&2
fi
exec kitty --config /etc/corebrum/kitty/kitty.conf "$@"
