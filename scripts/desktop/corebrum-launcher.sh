#!/usr/bin/env bash
# Super+Space. Refreshes the ROS entry, then opens Fuzzel.
set -euo pipefail

/usr/local/bin/corebrum-ros-menu refresh
/usr/local/bin/corebrum-realsense-menu refresh
/usr/local/bin/corebrum-chromium-menu refresh
/usr/local/bin/corebrum-agents-menu refresh
/usr/local/bin/corebrum-waypaper-menu refresh
/usr/local/bin/corebrum-keys-menu refresh
data_dir="$(/usr/local/bin/corebrum-ros-menu data-dir)"
if [[ -n "${XDG_DATA_DIRS:-}" ]]; then
  export XDG_DATA_DIRS="${data_dir}:${XDG_DATA_DIRS}"
else
  export XDG_DATA_DIRS="${data_dir}:/usr/local/share:/usr/share"
fi
# Fuzzel rejects an empty prompt in its ini file, so the blank search field is set here.
exec fuzzel --config /etc/corebrum/fuzzel/fuzzel.ini --prompt ''
