#!/usr/bin/env bash
# Validate a completed Phase 5 install. Safe to run as a normal user.
# This does not prove a second machine can exchange messages.
set -euo pipefail

COREBRUM_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=../lib/log.sh
source "${COREBRUM_ROOT}/scripts/lib/log.sh"
# shellcheck source=../lib/manifest.sh
source "${COREBRUM_ROOT}/scripts/lib/manifest.sh"

DRY_RUN=0
failed=0
packages=()
rmw=""
count=""
distro=""
manifest=""
sources="/etc/apt/sources.list.d/ros2.sources"
fingerprint="C1CF6E31E6BADE8868B172B4F42ED6FBAB17C654"

if [[ -f /etc/corebrum/ros/distro ]]; then
  distro="$(tr -d '[:space:]' < /etc/corebrum/ros/distro)"
elif [[ -x /opt/ros/lyrical/bin/ros2 ]]; then
  distro="lyrical"
elif [[ -x /opt/ros/jazzy/bin/ros2 ]]; then
  distro="jazzy"
fi
case "$distro" in
  jazzy) manifest="${COREBRUM_ROOT}/manifests/packages/ros.txt" ;;
  lyrical) manifest="${COREBRUM_ROOT}/manifests/packages/ros-lyrical.txt" ;;
  *)
    corebrum_log "missing: ROS distro"
    failed=1
    ;;
esac
if [[ -n "$manifest" ]]; then
  corebrum_load_manifest "$manifest" packages
fi

for pkg in "${packages[@]}"; do
  status="$(dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null || true)"
  if [[ "$status" == "install ok installed" ]]; then
    corebrum_log "ok: ${pkg}"
  else
    corebrum_log "missing: ${pkg}"
    failed=1
  fi
done

for pkg in \
  ros-jazzy-desktop ros-jazzy-rviz2 ros-jazzy-gazebo-ros-pkgs ros-jazzy-realsense2-camera \
  ros-lyrical-desktop ros-lyrical-rviz2 ros-lyrical-gazebo-ros-pkgs ros-lyrical-realsense2-camera
do
  status="$(dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null || true)"
  if [[ "$status" == "install ok installed" ]]; then
    corebrum_log "unexpected: ${pkg} is outside Phase 5"
    failed=1
  fi
done

status="$(dpkg-query -W -f='${Status}' ros2-apt-source 2>/dev/null || true)"
if [[ "$status" == "install ok installed" ]]; then
  corebrum_log "ok: ros2-apt-source"
else
  corebrum_log "missing: ros2-apt-source"
  failed=1
fi

if [[ -f /usr/share/keyrings/ros2-archive-keyring.gpg ]]; then
  got="$(gpg --batch --show-keys --with-colons /usr/share/keyrings/ros2-archive-keyring.gpg | awk -F: '/^fpr:/ { print $10; exit }' || true)"
  if [[ "$got" == "$fingerprint" ]]; then
    corebrum_log "ok: ROS apt key"
  else
    corebrum_log "missing: ROS apt key fingerprint"
    failed=1
  fi
else
  corebrum_log "missing: /usr/share/keyrings/ros2-archive-keyring.gpg"
  failed=1
fi

if [[ -L "$sources" ]] && [[ "$(readlink -f "$sources")" == "/usr/share/ros-apt-source/ros2.sources" ]]; then
  corebrum_log "ok: ROS apt source"
else
  corebrum_log "missing: ${sources}"
  failed=1
fi

if [[ -f /etc/corebrum/ros/rmw ]]; then
  rmw="$(tr -d '[:space:]' < /etc/corebrum/ros/rmw)"
  case "$rmw" in
    rmw_zenoh_cpp | rmw_fastrtps_cpp)
      corebrum_log "ok: rmw ${rmw}"
      ;;
    *)
      corebrum_log "missing: supported RMW in /etc/corebrum/ros/rmw"
      failed=1
      ;;
  esac
else
  corebrum_log "missing: /etc/corebrum/ros/rmw"
  failed=1
fi

if [[ -f /etc/profile.d/corebrum-ros.sh ]]; then
  corebrum_log "ok: /etc/profile.d/corebrum-ros.sh"
else
  corebrum_log "missing: /etc/profile.d/corebrum-ros.sh"
  failed=1
fi

if [[ -f /etc/ros/rosdep/sources.list.d/20-default.list ]]; then
  corebrum_log "ok: rosdep init"
else
  corebrum_log "missing: rosdep init"
  failed=1
fi

if [[ -n "$distro" && -x "/opt/ros/${distro}/bin/ros2" ]]; then
  corebrum_log "ok: command ros2"
else
  corebrum_log "missing: command ros2"
  failed=1
fi
for cmd in colcon rosdep; do
  if command -v "$cmd" >/dev/null 2>&1; then
    corebrum_log "ok: command ${cmd}"
  else
    corebrum_log "missing: command ${cmd}"
    failed=1
  fi
done

enabled="$(systemctl is-enabled corebrum-zenoh-router.service 2>/dev/null || true)"
active="$(systemctl is-active corebrum-zenoh-router.service 2>/dev/null || true)"
if [[ "$enabled" == "enabled" && "$active" == "active" ]]; then
  corebrum_log "ok: corebrum-zenoh-router.service"
else
  corebrum_log "missing: corebrum-zenoh-router.service (${enabled:-disabled}/${active:-inactive})"
  failed=1
fi

count="$(pgrep -c -x rmw_zenohd 2>/dev/null || true)"
if [[ "${count:-0}" -eq 1 ]]; then
  corebrum_log "ok: one Zenoh router"
else
  corebrum_log "missing: one rmw_zenohd process (found ${count:-0})"
  failed=1
fi

if [[ "$failed" -ne 0 ]]; then
  corebrum_log "ros validation failed"
  exit 1
fi
corebrum_log "ros validation passed; topics, services, and actions were checked at install time. A second machine is documented in docs/installation/ros.md and was not required for this check"
