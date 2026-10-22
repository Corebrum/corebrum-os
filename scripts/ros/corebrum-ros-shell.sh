#!/usr/bin/env bash
# Interactive login shell with the Corebrum ROS environment.
if [[ ! -f /opt/ros/jazzy/setup.bash && ! -f /opt/ros/lyrical/setup.bash ]]; then
  echo "ROS 2 is not installed. Run: sudo corebrum install ros" >&2
  exit 1
fi
exec bash --login -i
