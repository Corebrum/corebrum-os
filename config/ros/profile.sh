# shellcheck shell=bash
# Managed by Corebrum OS.
# Login shells source this file. It does not write to the home directory.
if [[ -f /usr/local/lib/corebrum/ros-env.sh ]]; then
  # shellcheck disable=SC1091
  source /usr/local/lib/corebrum/ros-env.sh
  _corebrum_ros_setup="$(corebrum_ros_setup_file || true)"
  if [[ -n "${_corebrum_ros_setup}" ]]; then
    set +u
    # shellcheck disable=SC1090
    source "${_corebrum_ros_setup}"
  fi
  unset _corebrum_ros_setup
fi
if [[ -f /etc/corebrum/ros/rmw ]]; then
  _corebrum_rmw="$(tr -d '[:space:]' < /etc/corebrum/ros/rmw)"
  case "$_corebrum_rmw" in
    rmw_zenoh_cpp | rmw_fastrtps_cpp)
      export RMW_IMPLEMENTATION="$_corebrum_rmw"
      ;;
  esac
  unset _corebrum_rmw
fi
export ROS_DOMAIN_ID="${ROS_DOMAIN_ID:-0}"
