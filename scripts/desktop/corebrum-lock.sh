#!/usr/bin/env bash
# Lock the Hyprland session. The config stays under /etc/corebrum.
set -euo pipefail

if ! command -v hyprlock >/dev/null 2>&1; then
  printf 'corebrum-lock: hyprlock is not installed\n' >&2
  exit 1
fi

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "${here}/corebrum-drm.sh" ]]; then
  # shellcheck source=corebrum-drm.sh
  source "${here}/corebrum-drm.sh"
elif [[ -f /usr/local/lib/corebrum/drm.sh ]]; then
  # shellcheck source=corebrum-drm.sh
  source /usr/local/lib/corebrum/drm.sh
fi
if declare -F corebrum_export_vc4_devices >/dev/null 2>&1; then
  corebrum_export_vc4_devices
fi

exec hyprlock --config /etc/corebrum/hypr/hyprlock.conf
