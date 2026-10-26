#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=../../scripts/lib/vc4.sh
source "${ROOT}/scripts/lib/vc4.sh"
# shellcheck source=../../scripts/desktop/corebrum-drm.sh
source "${ROOT}/scripts/desktop/corebrum-drm.sh"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

mkdir -p "${tmp}/drm/card0/device" "${tmp}/drm/card1/device" "${tmp}/drm/card1-HDMI-A-1"
printf 'DRIVER=v3d\n' >"${tmp}/drm/card0/device/uevent"
printf 'DRIVER=vc4-drm\n' >"${tmp}/drm/card1/device/uevent"
printf 'connected\n' >"${tmp}/drm/card1-HDMI-A-1/status"

card="$(COREBRUM_DRM_SYS="${tmp}/drm" corebrum_vc4_card)"
if [[ "$card" != "/dev/dri/card1" ]]; then
  echo "FAIL: vc4 scanout should be card1 (got ${card:-nothing})" >&2
  exit 1
fi

if COREBRUM_DRM_SYS="${tmp}/empty" corebrum_vc4_card; then
  echo "FAIL: a machine without vc4 should not report a card" >&2
  exit 1
fi

printf 'monitor=,preferred,auto,1\n' >"${tmp}/hyprland.conf"
COREBRUM_DRM_SYS="${tmp}/empty" generated="$(corebrum_hyprland_config "${tmp}/hyprland.conf")"
if [[ "$generated" != "${tmp}/hyprland.conf" ]]; then
  echo "FAIL: x86 session should keep the system Hyprland config" >&2
  exit 1
fi

export XDG_RUNTIME_DIR="${tmp}/run"
COREBRUM_DRM_SYS="${tmp}/drm" generated="$(corebrum_hyprland_config "${tmp}/hyprland.conf")"
if [[ "$generated" == "${tmp}/hyprland.conf" ]]; then
  echo "FAIL: Pi session should use a generated config" >&2
  exit 1
fi
if ! grep -q 'env = AQ_DRM_DEVICES,/dev/dri/card1' "$generated"; then
  echo "FAIL: generated config does not select the vc4 device" >&2
  exit 1
fi
if ! grep -q 'no_hardware_cursors = true' "$generated"; then
  echo "FAIL: generated config does not disable hardware cursors" >&2
  exit 1
fi
if grep -q 'no_hardware_cursors' "${tmp}/hyprland.conf"; then
  echo "FAIL: the system Hyprland config was modified" >&2
  exit 1
fi
if grep -q 'no_hardware_cursors' "${ROOT}/config/hypr/hyprland.conf"; then
  echo "FAIL: the shared Hyprland config disables hardware cursors" >&2
  exit 1
fi

echo "ok: vc4"
