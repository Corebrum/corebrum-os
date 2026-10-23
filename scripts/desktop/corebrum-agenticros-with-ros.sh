#!/usr/bin/env bash
# Source Corebrum ROS and force the Zenoh RMW, then exec the remaining arguments.
# AgenticROS and every agent MCP server start through this wrapper.
set -euo pipefail
if [[ -f /etc/profile.d/corebrum-node.sh ]]; then
  # shellcheck disable=SC1091
  source /etc/profile.d/corebrum-node.sh || true
fi
set +u
if [[ -f /usr/local/lib/corebrum/ros-env.sh ]]; then
  # shellcheck disable=SC1091
  source /usr/local/lib/corebrum/ros-env.sh
  _corebrum_ros_setup="$(corebrum_ros_setup_file || true)"
  if [[ -n "${_corebrum_ros_setup}" ]]; then
    # shellcheck disable=SC1090
    source "${_corebrum_ros_setup}"
  fi
  unset _corebrum_ros_setup
fi
export RMW_IMPLEMENTATION=rmw_zenoh_cpp
export ROS_DOMAIN_ID="${ROS_DOMAIN_ID:-0}"
exec "$@"
