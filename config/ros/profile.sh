# shellcheck shell=bash
# Managed by Corebrum OS.
# Login shells source this file. It does not write to the home directory.
if [[ -f /opt/ros/jazzy/setup.bash ]]; then
  set +u
  # shellcheck disable=SC1091
  source /opt/ros/jazzy/setup.bash
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
