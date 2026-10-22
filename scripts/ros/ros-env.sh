#!/usr/bin/env bash
# Locate the ROS setup file selected for this machine.
# Sourced by the ROS profile and the Zenoh helpers. Do not execute it.
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  echo "source scripts/ros/ros-env.sh from another script" >&2
  exit 1
fi

corebrum_ros_setup_file() {
  local distro="" candidate
  if [[ -f /etc/corebrum/ros/distro ]]; then
    distro="$(tr -d '[:space:]' < /etc/corebrum/ros/distro)"
    if [[ -z "$distro" || "$distro" == *[!a-z]* ]]; then
      distro=""
    fi
  fi
  if [[ -n "$distro" && -f "/opt/ros/${distro}/setup.bash" ]]; then
    printf '%s\n' "/opt/ros/${distro}/setup.bash"
    return 0
  fi
  for candidate in jazzy lyrical; do
    if [[ -f "/opt/ros/${candidate}/setup.bash" ]]; then
      printf '%s\n' "/opt/ros/${candidate}/setup.bash"
      return 0
    fi
  done
  return 1
}
