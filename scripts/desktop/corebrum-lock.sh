#!/usr/bin/env bash
# Lock the Sway session. The config stays under /etc/corebrum.
set -euo pipefail

if ! command -v gtklock >/dev/null 2>&1; then
  printf 'corebrum-lock: gtklock is not installed\n' >&2
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

if [[ ! -f /etc/corebrum/gtklock/config.ini ]]; then
  printf 'corebrum-lock: missing /etc/corebrum/gtklock/config.ini\n' >&2
  exit 1
fi

exec gtklock --config /etc/corebrum/gtklock/config.ini
