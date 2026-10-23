#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
menu="${ROOT}/scripts/desktop/corebrum-ros-menu.sh"
catalog="${ROOT}/manifests/packages/ros-tools.conf"

assert_eq() {
  local got="$1" expected="$2" message="$3"
  if [[ "$got" != "$expected" ]]; then
    printf 'FAIL: %s\n got: %q\n expected: %q\n' "$message" "$got" "$expected" >&2
    exit 1
  fi
}

for suffix in rviz2 ros-gz nav2-bringup moveit; do
  if ! grep -q "|${suffix}|" "$catalog"; then
    echo "FAIL: ROS tool list is missing ${suffix}" >&2
    exit 1
  fi
done
if ! grep -q 'exec /usr/local/lib/corebrum/with-ros.sh' "$menu"; then
  echo "FAIL: a launched ROS tool still opens a terminal" >&2
  exit 1
fi
if ! grep -q 'QT_QPA_PLATFORM=xcb rviz2' "$catalog"; then
  echo "FAIL: RViz is not launched through XWayland" >&2
  exit 1
fi
if ! grep -q 'QT_QPA_PLATFORM=xcb ros2 launch ros_gz_sim' "$catalog"; then
  echo "FAIL: Gazebo is not launched through XWayland" >&2
  exit 1
fi
if grep -Eq 'ros-jazzy-desktop|ros-lyrical-desktop|realsense' "$catalog"; then
  echo "FAIL: ROS tool list includes RealSense or a ROS desktop metapackage" >&2
  exit 1
fi

export COREBRUM_ROS_MENU_STUB=1
export COREBRUM_ROS_DISTRO=lyrical
export COREBRUM_ROS_TOOLS_FILE="$catalog"
export COREBRUM_ROS_MENU_INSTALLED=""

assert_eq "$("$menu" entry-name)" "ROS 2   install" "ROS 2 is offered for install"
assert_eq "$("$menu" labels)" "$(printf '%s\n' \
  "RViz   install" \
  "Gazebo   install" \
  "Nav2   install" \
  "MoveIt   install")" "every tool shows an install indicator"

export COREBRUM_ROS_MENU_INSTALLED="ros-lyrical-ros-base ros-lyrical-rviz2"
assert_eq "$("$menu" entry-name)" "ROS" "installed ROS 2 has no install indicator"
assert_eq "$("$menu" labels)" "$(printf '%s\n' \
  "RViz" \
  "Gazebo   install" \
  "Nav2   install" \
  "MoveIt   install")" "installed RViz launches and the other tools still install"

runtime="$(mktemp -d)"
export XDG_RUNTIME_DIR="$runtime"
export COREBRUM_ZENOH_MENU_READY=0
"$menu" refresh
if ! grep -q '^Name=ROS$' "${runtime}/corebrum/applications/corebrum-ros.desktop"; then
  echo "FAIL: refreshed desktop entry did not name installed ROS" >&2
  exit 1
fi
if [[ -e "${runtime}/corebrum/applications/corebrum-zenoh-network.desktop" ]]; then
  echo "FAIL: Zenoh network is listed before the Zenoh CLI is installed" >&2
  exit 1
fi
export COREBRUM_ZENOH_MENU_READY=1
"$menu" refresh
if ! grep -q '^Name=Zenoh network$' "${runtime}/corebrum/applications/corebrum-zenoh-network.desktop"; then
  echo "FAIL: Zenoh network is missing after ROS and the CLI are installed" >&2
  exit 1
fi
if ! grep -q '^Exec=/usr/local/bin/zenoh network$' "${runtime}/corebrum/applications/corebrum-zenoh-network.desktop"; then
  echo "FAIL: Zenoh network does not run zenoh network" >&2
  exit 1
fi
export COREBRUM_ROS_MENU_INSTALLED=""
"$menu" refresh
if [[ -e "${runtime}/corebrum/applications/corebrum-zenoh-network.desktop" ]]; then
  echo "FAIL: Zenoh network stays listed when ROS is not installed" >&2
  exit 1
fi
rm -rf "$runtime"

echo "ok: ros-menu"
