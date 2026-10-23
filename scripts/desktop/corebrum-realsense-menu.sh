#!/usr/bin/env bash
# Super+Space RealSense entry. Install the SDK, or open the RealSense submenu.
set -euo pipefail

COREBRUM_REALSENSE_INSTALL_MARK='   install'

corebrum_realsense_menu_die() {
  printf 'corebrum-realsense-menu: %s\n' "$1" >&2
  exit 1
}

corebrum_realsense_menu_distro() {
  local distro="" codename
  if [[ -n "${COREBRUM_ROS_DISTRO:-}" ]]; then
    printf '%s\n' "$COREBRUM_ROS_DISTRO"
    return 0
  fi
  if [[ -f /etc/corebrum/ros/distro ]]; then
    distro="$(tr -d '[:space:]' < /etc/corebrum/ros/distro)"
  fi
  if [[ "$distro" =~ ^[a-z]+$ ]]; then
    printf '%s\n' "$distro"
    return 0
  fi
  # shellcheck disable=SC1091
  codename="$(. /etc/os-release && printf '%s' "${VERSION_CODENAME:-}")"
  case "$codename" in
    noble) printf 'jazzy\n' ;;
    resolute) printf 'lyrical\n' ;;
    *) return 1 ;;
  esac
}

corebrum_realsense_menu_pkg_installed() {
  local pkg="$1" status
  status="$(dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null || true)"
  [[ "$status" == "install ok installed" ]]
}

corebrum_realsense_menu_ready() {
  local distro
  if [[ "${COREBRUM_REALSENSE_STUB:-0}" == 1 ]]; then
    [[ "${COREBRUM_REALSENSE_READY:-0}" == 1 ]]
    return
  fi
  distro="$(corebrum_realsense_menu_distro)" || return 1
  corebrum_realsense_menu_pkg_installed librealsense2-utils || return 1
  corebrum_realsense_menu_pkg_installed "ros-${distro}-librealsense2" || return 1
  corebrum_realsense_menu_pkg_installed "ros-${distro}-realsense2-camera" || return 1
  command -v realsense-viewer >/dev/null 2>&1 || return 1
  python3 -c 'import pyrealsense2' >/dev/null 2>&1
}

corebrum_realsense_menu_entry_name() {
  if corebrum_realsense_menu_ready; then
    printf 'RealSense\n'
  else
    printf 'RealSense%s\n' "$COREBRUM_REALSENSE_INSTALL_MARK"
  fi
}

corebrum_realsense_menu_data_dir() {
  local root="${XDG_RUNTIME_DIR:-/tmp/corebrum-launcher-${UID}}"
  printf '%s\n' "${root}/corebrum"
}

corebrum_realsense_menu_refresh() {
  local dir name
  dir="$(corebrum_realsense_menu_data_dir)/applications"
  name="$(corebrum_realsense_menu_entry_name)"
  mkdir -p "$dir"
  cat >"${dir}/corebrum-realsense.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=${name}
GenericName=${name}
Comment=RealSense viewer, ROS camera driver, and pyrealsense2
Exec=/usr/local/bin/corebrum-realsense-menu open
Icon=camera-video
Terminal=false
Categories=Science;Development;
StartupNotify=false
EOF
  corebrum_realsense_menu_write_tools "$dir"
}

corebrum_realsense_menu_clear_tools() {
  local dir="$1" file
  shopt -s nullglob
  for file in "${dir}"/corebrum-realsense-tool-*.desktop; do
    rm -f "$file"
  done
  shopt -u nullglob
}

corebrum_realsense_menu_write_tools() {
  local dir="$1" id label
  corebrum_realsense_menu_clear_tools "$dir"
  corebrum_realsense_menu_ready || return 0
  while IFS='|' read -r id label; do
    [[ -n "$id" ]] || continue
    cat >"${dir}/corebrum-realsense-tool-${id}.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=${label}
GenericName=${label}
Keywords=${id};${label};
Comment=RealSense
Exec=/usr/local/bin/corebrum-realsense-menu launch ${id}
Icon=camera-video
Terminal=false
Categories=Science;Development;
StartupNotify=false
EOF
  done <<'EOF'
viewer|RealSense Viewer
ros|RealSense ROS
EOF
}

corebrum_realsense_menu_terminal() {
  local script="$1"
  if [[ "${COREBRUM_REALSENSE_STUB:-0}" == 1 ]]; then
    printf '%s\n' "$script"
    return 0
  fi
  exec /usr/local/bin/corebrum-terminal bash -c "$script"
}

corebrum_realsense_menu_labels() {
  printf '%s\n' "RealSense Viewer" "RealSense ROS"
}

corebrum_realsense_menu_run() {
  local choice="$1"
  case "$choice" in
    "RealSense Viewer")
      if [[ "${COREBRUM_REALSENSE_STUB:-0}" == 1 ]]; then
        printf 'realsense-viewer\n'
        return 0
      fi
      # The viewer is linked against the /usr librealsense library.
      exec realsense-viewer
      ;;
    "RealSense ROS")
      if [[ "${COREBRUM_REALSENSE_STUB:-0}" == 1 ]]; then
        printf 'ros2 launch realsense2_camera rs_launch.py\n'
        return 0
      fi
      # A login shell sources the ROS profile. The terminal stays open with the launch log.
      exec /usr/local/bin/corebrum-terminal bash --login -c 'ros2 launch realsense2_camera rs_launch.py'
      ;;
    *)
      corebrum_realsense_menu_die "unknown RealSense menu choice"
      ;;
  esac
}

corebrum_realsense_menu_open_tools() {
  local choice=""
  if [[ "${COREBRUM_REALSENSE_STUB:-0}" == 1 ]]; then
    if [[ -n "${COREBRUM_REALSENSE_CHOICE:-}" ]]; then
      corebrum_realsense_menu_run "$COREBRUM_REALSENSE_CHOICE"
      return 0
    fi
    corebrum_realsense_menu_labels
    return 0
  fi
  choice="$(corebrum_realsense_menu_labels | fuzzel \
    --config /etc/corebrum/fuzzel/fuzzel.ini \
    --dmenu \
    --prompt 'RealSense  ' \
    --width 48 \
    --lines 4)" || return 0
  [[ -n "$choice" ]] || return 0
  corebrum_realsense_menu_run "$choice"
}

corebrum_realsense_menu_open() {
  local script="/usr/local/lib/corebrum/realsense-install.sh"
  if corebrum_realsense_menu_ready; then
    corebrum_realsense_menu_open_tools
    return 0
  fi
  if [[ "${COREBRUM_REALSENSE_STUB:-0}" != 1 && ! -x "$script" ]]; then
    corebrum_realsense_menu_die "the RealSense installer is not installed"
  fi
  corebrum_realsense_menu_terminal "$(cat <<EOF
set +e
sudo ${script}
ec=\$?
set -e
printf '\\n'
if [ "\$ec" -eq 0 ]; then
  printf '%s\\n' "RealSense is installed. Press Super+Space and choose RealSense."
else
  printf 'Install failed (%s).\\n' "\$ec"
fi
read -r -p 'Press Enter to close. '
EOF
)"
}

corebrum_realsense_menu_launch_id() {
  local id="$1"
  [[ "$id" =~ ^[a-z0-9-]+$ ]] || corebrum_realsense_menu_die "invalid RealSense action"
  if ! corebrum_realsense_menu_ready; then
    corebrum_realsense_menu_open
    return 0
  fi
  case "$id" in
    viewer) corebrum_realsense_menu_run "RealSense Viewer" ;;
    ros) corebrum_realsense_menu_run "RealSense ROS" ;;
    *) corebrum_realsense_menu_die "unknown RealSense action ${id}" ;;
  esac
}

usage() {
  cat <<'EOF'
Usage: corebrum-realsense-menu refresh|open|launch ID|entry-name|labels|data-dir
EOF
}

cmd="${1:-}"
case "$cmd" in
  refresh) corebrum_realsense_menu_refresh ;;
  open) corebrum_realsense_menu_open ;;
  launch) corebrum_realsense_menu_launch_id "${2:-}" ;;
  entry-name) corebrum_realsense_menu_entry_name ;;
  labels) corebrum_realsense_menu_labels ;;
  data-dir) corebrum_realsense_menu_data_dir ;;
  -h | --help | help) usage ;;
  *)
    usage >&2
    exit 1
    ;;
esac
