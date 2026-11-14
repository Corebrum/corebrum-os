#!/usr/bin/env bash
# Display backlight is chosen before the Mac Touch Bar backlight.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
lib="${ROOT}/scripts/lib/backlight.sh"
fail=0

# shellcheck source=/dev/null
source "$lib"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

mkdir -p "${tmpdir}/backlight"
ln -s /dev/null "${tmpdir}/backlight/appletb_backlight"
ln -s /dev/null "${tmpdir}/backlight/intel_backlight"

COREBRUM_BACKLIGHT_SYS_CLASS="${tmpdir}/backlight"
corebrum_backlight_class_dir() {
  printf '%s\n' "$COREBRUM_BACKLIGHT_SYS_CLASS"
}

device="$(corebrum_backlight_display_device)"
if [[ "$device" != intel_backlight ]]; then
  echo "FAIL: display device was ${device}, expected intel_backlight" >&2
  fail=1
fi

tb="$(corebrum_backlight_touchbar_device)"
if [[ "$tb" != appletb_backlight ]]; then
  echo "FAIL: touch bar device was ${tb}" >&2
  fail=1
fi

if [[ "$fail" -ne 0 ]]; then
  exit 1
fi
echo "backlight unit tests passed"