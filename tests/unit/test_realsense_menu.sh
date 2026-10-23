#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
menu="${ROOT}/scripts/desktop/corebrum-realsense-menu.sh"
launcher="${ROOT}/scripts/desktop/corebrum-launcher.sh"

assert_eq() {
  local got="$1" expected="$2" message="$3"
  if [[ "$got" != "$expected" ]]; then
    printf 'FAIL: %s\n got: %q\n expected: %q\n' "$message" "$got" "$expected" >&2
    exit 1
  fi
}

if ! grep -q '/usr/local/bin/corebrum-realsense-menu refresh' "$launcher"; then
  echo "FAIL: Super+Space does not refresh the RealSense entry" >&2
  exit 1
fi
if grep -q 'realsense' "${ROOT}/manifests/packages/ros-tools.conf"; then
  echo "FAIL: RealSense is still inside the ROS submenu" >&2
  exit 1
fi
if ! grep -q 'exec realsense-viewer' "$menu"; then
  echo "FAIL: RealSense Viewer does not launch realsense-viewer" >&2
  exit 1
fi
if ! grep -q "ros2 launch realsense2_camera rs_launch.py" "$menu"; then
  echo "FAIL: RealSense ROS does not launch rs_launch.py" >&2
  exit 1
fi
if ! grep -q 'corebrum-terminal bash --login -c' "$menu"; then
  echo "FAIL: RealSense ROS does not open a terminal" >&2
  exit 1
fi
if grep -q 'apt-cache madison "$pkg" | grep' "${ROOT}/scripts/desktop/corebrum-realsense-install.sh"; then
  echo "FAIL: the RealSense version check uses grep -q in a pipeline" >&2
  exit 1
fi
if ! grep -q '/usr/local/lib/corebrum/realsense-install.sh' "$menu"; then
  echo "FAIL: RealSense install does not run the RealSense installer" >&2
  exit 1
fi

export COREBRUM_REALSENSE_STUB=1
export COREBRUM_REALSENSE_READY=0
assert_eq "$("$menu" entry-name)" "RealSense   install" "missing RealSense is offered for install"
got="$("$menu" open)"
if ! grep -q '/usr/local/lib/corebrum/realsense-install.sh' <<<"$got"; then
  echo "FAIL: choosing RealSense did not start the installer" >&2
  exit 1
fi

export COREBRUM_REALSENSE_READY=1
assert_eq "$("$menu" entry-name)" "RealSense" "installed RealSense has no install indicator"
assert_eq "$("$menu" open)" "$(printf '%s\n' "RealSense Viewer" "RealSense ROS")" "installed RealSense opens the submenu"
export COREBRUM_REALSENSE_CHOICE="RealSense Viewer"
assert_eq "$("$menu" open)" "realsense-viewer" "RealSense Viewer launches the viewer"
export COREBRUM_REALSENSE_CHOICE="RealSense ROS"
assert_eq "$("$menu" open)" "ros2 launch realsense2_camera rs_launch.py" "RealSense ROS launches the camera driver"
unset COREBRUM_REALSENSE_CHOICE

runtime="$(mktemp -d)"
export XDG_RUNTIME_DIR="$runtime"
"$menu" refresh
if ! grep -q '^Name=RealSense$' "${runtime}/corebrum/applications/corebrum-realsense.desktop"; then
  echo "FAIL: refreshed desktop entry did not name installed RealSense" >&2
  exit 1
fi
if ! grep -q '^Exec=/usr/local/bin/corebrum-realsense-menu open$' "${runtime}/corebrum/applications/corebrum-realsense.desktop"; then
  echo "FAIL: RealSense desktop entry does not open the RealSense menu command" >&2
  exit 1
fi
viewer_entry="${runtime}/corebrum/applications/corebrum-realsense-tool-viewer.desktop"
if ! grep -q '^Name=RealSense Viewer$' "$viewer_entry"; then
  echo "FAIL: Super+Space does not list RealSense Viewer for search" >&2
  exit 1
fi
if ! grep -q '^Exec=/usr/local/bin/corebrum-realsense-menu launch viewer$' "$viewer_entry"; then
  echo "FAIL: choosing RealSense Viewer from search does not launch the viewer" >&2
  exit 1
fi
assert_eq "$("$menu" launch viewer)" "realsense-viewer" "typing the viewer launches it"
export COREBRUM_REALSENSE_READY=0
"$menu" refresh
if [[ -e "$viewer_entry" ]]; then
  echo "FAIL: RealSense Viewer stays listed before RealSense is installed" >&2
  exit 1
fi
rm -rf "$runtime"

echo "ok: realsense-menu"
