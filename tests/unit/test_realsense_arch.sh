#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
script="${ROOT}/scripts/desktop/corebrum-realsense-install.sh"

if grep -q 'pyrealsense2 wheels used here are x86_64 only' "$script"; then
  echo "FAIL: aarch64 still stops before the RealSense install" >&2
  exit 1
fi
if ! grep -q 'REALSENSE_SDK_VERSION="2.59.1-0~realsense.20271"' "$script"; then
  echo "FAIL: the x86_64 resolute RealSense pin was removed" >&2
  exit 1
fi
if ! grep -q 'REALSENSE_SDK_VERSION="2.59.1-0~realsense.20270"' "$script"; then
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
if ! grep -q 'COREBRUM_REALSENSE_ARM64_SDK_VERSION="2.59.1-0~realsense.9166"' "$script"; then
  echo "FAIL: the arm64 RealSense package pin is missing" >&2
  exit 1
fi
if ! grep -q 'COREBRUM_REALSENSE_SRC_COMMIT="625279aa1fe903528a818f48746ee47c1b5fefd3"' "$script"; then
  echo "FAIL: the arm64 Python binding commit is not pinned" >&2
  exit 1
fi
if ! grep -q 'Package: librealsense2 librealsense2-gl librealsense2-utils librealsense2-udev-rules librealsense2-dkms' "$script"; then
  echo "FAIL: the RealSense apt pin list changed" >&2
  exit 1
fi

bash -n "$script"

echo "ok: realsense-arch"
