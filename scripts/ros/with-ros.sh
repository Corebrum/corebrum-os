#!/usr/bin/env bash
# Run one command with the Corebrum ROS 2 environment.
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${here}/ros-env.sh"
setup="$(corebrum_ros_setup_file || true)"
if [[ -z "$setup" ]]; then
  echo "corebrum: ROS 2 is not installed" >&2
  exit 1
fi
# shellcheck disable=SC1090
source "$setup"
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
