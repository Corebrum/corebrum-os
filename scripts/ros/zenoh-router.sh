#!/usr/bin/env bash
# systemd ExecStart for the one Corebrum Zenoh router.
if [[ ! -f /opt/ros/jazzy/setup.bash ]]; then
  echo "corebrum-zenoh-router: ROS 2 Jazzy is not installed" >&2
  exit 1
fi
# shellcheck disable=SC1091
source /opt/ros/jazzy/setup.bash
export RMW_IMPLEMENTATION=rmw_zenoh_cpp
export ROS_DOMAIN_ID="${ROS_DOMAIN_ID:-0}"
exec ros2 run rmw_zenoh_cpp rmw_zenohd
