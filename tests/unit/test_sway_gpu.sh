#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=../../scripts/desktop/corebrum-drm.sh
source "${ROOT}/scripts/desktop/corebrum-drm.sh"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

printf '%s\n' 'nvidia 1675264 1 nvidia_modeset, Live 0x0 (O)' >"${tmp}/nvidia"
printf '%s\n' 'nvidia_drm 114688 0 - Live 0x0 (O)' >"${tmp}/nvidia-drm"
printf '%s\n' 'nouveau 1 0 - Live 0x0' >"${tmp}/nouveau"

unset WLR_NO_HARDWARE_CURSORS
if ! COREBRUM_PROC_MODULES="${tmp}/nvidia" corebrum_prepare_nvidia_sway; then
  echo "FAIL: the proprietary nvidia module should select --unsupported-gpu" >&2
  exit 1
fi
if [[ "${WLR_NO_HARDWARE_CURSORS:-}" != 1 ]]; then
  echo "FAIL: the proprietary nvidia module should disable hardware cursors" >&2
  exit 1
fi

unset WLR_NO_HARDWARE_CURSORS
if COREBRUM_PROC_MODULES="${tmp}/nvidia-drm" corebrum_prepare_nvidia_sway; then
  echo "FAIL: nvidia_drm alone is not the module Sway refuses" >&2
  exit 1
fi
if [[ -n "${WLR_NO_HARDWARE_CURSORS:-}" ]]; then
  echo "FAIL: nvidia_drm alone should leave the cursor setting alone" >&2
  exit 1
fi

if COREBRUM_PROC_MODULES="${tmp}/nouveau" corebrum_prepare_nvidia_sway; then
  echo "FAIL: nouveau should keep the normal Sway launch" >&2
  exit 1
fi

if COREBRUM_PROC_MODULES="${tmp}/missing" corebrum_prepare_nvidia_sway; then
  echo "FAIL: a missing modules file should keep the normal Sway launch" >&2
  exit 1
fi

echo "ok: sway gpu"
