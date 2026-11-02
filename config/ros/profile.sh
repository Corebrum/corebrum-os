# shellcheck shell=sh
# Managed by Corebrum OS.
# Login shells source this file. It does not write to the home directory.
# /etc/profile runs under /bin/sh (dash on Ubuntu). Only bash sources the
# ROS setup scripts, which are bash-only.
if [ -n "${BASH_VERSION:-}" ] && [ -f /usr/local/lib/corebrum/ros-env.sh ]; then
  # shellcheck disable=SC1091
  . /usr/local/lib/corebrum/ros-env.sh
  _corebrum_ros_setup="$(corebrum_ros_setup_file || true)"
  if [ -n "${_corebrum_ros_setup}" ]; then
    set +u
    # shellcheck disable=SC1090
    . "${_corebrum_ros_setup}"
  fi
  unset _corebrum_ros_setup
fi
if [ -f /etc/corebrum/ros/rmw ]; then
  _corebrum_rmw="$(tr -d '[:space:]' < /etc/corebrum/ros/rmw)"
  case "$_corebrum_rmw" in
    rmw_zenoh_cpp|rmw_fastrtps_cpp)
      export RMW_IMPLEMENTATION="$_corebrum_rmw"
      ;;
  esac
  unset _corebrum_rmw
fi
export ROS_DOMAIN_ID="${ROS_DOMAIN_ID:-0}"
