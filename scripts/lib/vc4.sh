#!/usr/bin/env bash
# Find the Raspberry Pi display device. Source this file; do not execute it.
# x86_64 machines have no vc4-drm node, so callers leave the session alone.
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  echo "source scripts/lib/vc4.sh from another script" >&2
  exit 1
fi

# Print /dev/dri/cardN for the vc4 scanout device. card0 on a Pi 5 is v3d and
# has no HDMI connector. COREBRUM_DRM_SYS overrides /sys/class/drm in tests.
corebrum_vc4_card() {
  local root="${1:-}"
  local sys name driver
  [[ -n "$root" ]] || root="${COREBRUM_DRM_SYS:-/sys/class/drm}"
  for sys in "$root"/card[0-9] "$root"/card[0-9][0-9]; do
    [[ -e "$sys" ]] || continue
    name="${sys##*/}"
    [[ "$name" =~ ^card[0-9]+$ ]] || continue
    [[ -r "${sys}/device/uevent" ]] || continue
    driver="$(awk -F= '$1=="DRIVER" { print $2; exit }' "${sys}/device/uevent")"
    if [[ "$driver" == "vc4-drm" ]]; then
      printf '/dev/dri/%s\n' "$name"
      return 0
    fi
  done
  return 1
}
