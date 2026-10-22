#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

if [[ "$(tr -d '[:space:]' <"${ROOT}/config/ros/rmw")" != "rmw_zenoh_cpp" ]]; then
  echo "FAIL: default RMW is not rmw_zenoh_cpp" >&2
  exit 1
fi
if [[ "$(tr -d '[:space:]' <"${ROOT}/config/ros/rmw-fastrtps")" != "rmw_fastrtps_cpp" ]]; then
  echo "FAIL: DDS fallback is not rmw_fastrtps_cpp" >&2
  exit 1
fi
if [[ "$(grep -c '^ExecStart=' "${ROOT}/config/systemd/corebrum-zenoh-router.service")" -ne 1 ]]; then
  echo "FAIL: Zenoh unit does not have one ExecStart" >&2
  exit 1
fi
if ! grep -q '^Restart=on-failure$' "${ROOT}/config/systemd/corebrum-zenoh-router.service"; then
  echo "FAIL: Zenoh unit does not restart on failure" >&2
  exit 1
fi
if grep -Eq 'bashrc|HOME' "${ROOT}/config/ros/profile.sh"; then
  echo "FAIL: ROS profile mentions a user home or bashrc" >&2
  exit 1
fi
if grep -q 'releases/latest' "${ROOT}/scripts/lib/ros.sh"; then
  echo "FAIL: ROS apt source follows the latest GitHub release" >&2
  exit 1
fi
if ! grep -q 'f31d84adf5054c7d60ded0e82c0f776a77ea33af53d08f40b9ad7c94cca55296' "${ROOT}/scripts/lib/ros.sh"; then
  echo "FAIL: ROS apt source checksum is not pinned" >&2
  exit 1
fi
if ! grep -q 'C1CF6E31E6BADE8868B172B4F42ED6FBAB17C654' "${ROOT}/manifests/versions/ros.txt"; then
  echo "FAIL: versions file does not record the ROS key fingerprint" >&2
  exit 1
fi

echo "ok: ros-config"
