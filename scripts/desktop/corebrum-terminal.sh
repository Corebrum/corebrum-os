#!/usr/bin/env bash
# Kitty with the Corebrum system config. Hyprland binds this command.
# A plain window uses Kitty's login shell, which loads the node and ROS
# profiles after the window is up. A command passed in (bash -c from a menu)
# is not a login shell, so those profiles are loaded here and inherited.
set -euo pipefail
if [[ "$#" -gt 0 ]]; then
  if [[ -f /etc/profile.d/corebrum-node.sh ]]; then
    # shellcheck disable=SC1091
    source /etc/profile.d/corebrum-node.sh || echo "corebrum-terminal: node profile failed" >&2
  fi
  if [[ -f /etc/profile.d/corebrum-ros.sh ]]; then
    # shellcheck disable=SC1091
    source /etc/profile.d/corebrum-ros.sh || echo "corebrum-terminal: ROS profile failed" >&2
  fi
fi
exec kitty --config /etc/corebrum/kitty/kitty.conf "$@"
