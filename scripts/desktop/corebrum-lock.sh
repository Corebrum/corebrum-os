#!/usr/bin/env bash
# Lock the Hyprland session. The config stays under /etc/corebrum.
set -euo pipefail

if ! command -v hyprlock >/dev/null 2>&1; then
  printf 'corebrum-lock: hyprlock is not installed\n' >&2
  exit 1
fi

exec hyprlock --config /etc/corebrum/hypr/hyprlock.conf
