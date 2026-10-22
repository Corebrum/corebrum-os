#!/usr/bin/env bash
# Run one command with the Corebrum ROS 2 environment.
if [[ ! -f /opt/ros/jazzy/setup.bash ]]; then
  echo "corebrum: ROS 2 Jazzy is not installed" >&2
  exit 1
fi
# shellcheck disable=SC1091
source /opt/ros/jazzy/setup.bash
if [[ -n "${COREBRUM_RMW_IMPLEMENTATION:-}" ]]; then
  export RMW_IMPLEMENTATION="$COREBRUM_RMW_IMPLEMENTATION"
elif [[ -f /etc/corebrum/ros/rmw ]]; then
  RMW_IMPLEMENTATION="$(tr -d '[:space:]' < /etc/corebrum/ros/rmw)"
  export RMW_IMPLEMENTATION
else
  export RMW_IMPLEMENTATION=rmw_zenoh_cpp
fi
export ROS_DOMAIN_ID="${ROS_DOMAIN_ID:-0}"
exec "$@"
