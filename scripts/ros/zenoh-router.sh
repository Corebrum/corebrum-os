#!/usr/bin/env bash
# systemd ExecStart for the one Corebrum Zenoh router.
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${here}/ros-env.sh"
setup="$(corebrum_ros_setup_file || true)"
if [[ -z "$setup" ]]; then
  echo "corebrum-zenoh-router: ROS 2 is not installed" >&2
  exit 1
fi
# shellcheck disable=SC1090
source "$setup"
export RMW_IMPLEMENTATION=rmw_zenoh_cpp
export ROS_DOMAIN_ID="${ROS_DOMAIN_ID:-0}"
exec ros2 run rmw_zenoh_cpp rmw_zenohd
