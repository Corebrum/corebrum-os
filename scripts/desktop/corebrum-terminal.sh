#!/usr/bin/env bash
# Kitty with the Corebrum system config. Hyprland binds this command.
set -euo pipefail
exec kitty --config /etc/corebrum/kitty/kitty.conf "$@"
