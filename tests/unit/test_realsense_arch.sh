#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
script="${ROOT}/scripts/desktop/corebrum-realsense-install.sh"

if grep -q 'pyrealsense2 wheels used here are x86_64 only' "$script"; then
  echo "FAIL: aarch64 still stops before the RealSense install" >&2
  exit 1
fi
if ! grep -q 'REALSENSE_SDK_VERSION="2.59.2-0~realsense.20562"' "$script"; then
  echo "FAIL: the x86_64 resolute RealSense pin was removed" >&2
  exit 1
fi
if ! grep -q 'REALSENSE_SDK_VERSION="2.59.2-0~realsense.20561"' "$script"; then
  echo "FAIL: the x86_64 noble RealSense pin was removed" >&2
  exit 1
fi
if ! grep -q 'REALSENSE_DKMS_VERSION="1.3.33-noble"' "$script"; then
  echo "FAIL: noble x86_64 still needs the dkms pin" >&2
  exit 1
fi
if ! grep -q 'pyrealsense2==${COREBRUM_REALSENSE_PY}' "$script"; then
  echo "FAIL: the PyPI pin is no longer what pip installs" >&2
  exit 1
fi
if ! grep -q 'no x86_64 wheel for pyrealsense2' "$script"; then
  echo "FAIL: x86_64 still needs to reject an unsupported Python" >&2
  exit 1
fi
if ! grep -q 'COREBRUM_REALSENSE_ARM64_SDK_VERSION="2.59.2-0~realsense.9377"' "$script"; then
  echo "FAIL: the arm64 RealSense package pin is missing" >&2
  exit 1
fi
if ! grep -q 'COREBRUM_REALSENSE_SRC_COMMIT="e535e2445cfd00c31f67761ec13e0f99cb31c2dc"' "$script"; then
  echo "FAIL: the arm64 Python binding commit is not pinned" >&2
  exit 1
fi
# The apt preferences hold the SDK at the installer pin so Updates → Ubuntu
# (apt-get upgrade) cannot move it ahead of pyrealsense2.
pin="$(bash -c 'source "$1"; realsense_pin_text 2.59.2-0~realsense.20561 1.3.33-noble' _ "$script")"
expected_sdk='Package: librealsense2 librealsense2-gl librealsense2-utils librealsense2-udev-rules
Pin: version 2.59.2-0~realsense.20561
Pin-Priority: 990'
expected_dkms='Package: librealsense2-dkms
Pin: version 1.3.33-noble
Pin-Priority: 990'
expected_rest='Package: *
Pin: origin librealsense.realsenseai.com
Pin-Priority: 100'
for block in "$expected_sdk" "$expected_dkms" "$expected_rest"; do
  if [[ "$pin" != *"$block"* ]]; then
    printf 'FAIL: RealSense apt preferences are missing:\n%s\n' "$block" >&2
    exit 1
  fi
done
if grep -q 'Pin-Priority: 500' <<<"$pin"; then
  echo "FAIL: RealSense packages float with the archive again" >&2
  exit 1
fi
nodkms="$(bash -c 'source "$1"; realsense_pin_text 2.59.2-0~realsense.9377 ""' _ "$script")"
if grep -q 'librealsense2-dkms' <<<"$nodkms"; then
  echo "FAIL: dkms is held on a target that does not install it" >&2
  exit 1
fi
if ! grep -q 'realsense_pin_text "$REALSENSE_SDK_VERSION" "${REALSENSE_DKMS_VERSION:-}"' "$script"; then
  echo "FAIL: the installer does not write the pin for the version it installs" >&2
  exit 1
fi

bash -n "$script"

echo "ok: realsense-arch"
