#!/usr/bin/env bash
# Super+Space Corebrum Synapse entry. Hidden until ROS is installed.
set -euo pipefail

COREBRUM_SYNAPSE_INSTALL_MARK='   install'

corebrum_synapse_menu_die() {
  printf 'corebrum-synapse-menu: %s\n' "$1" >&2
  exit 1
}

corebrum_synapse_menu_distro() {
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

corebrum_synapse_menu_pkg_installed() {
  local pkg="$1" status
  status="$(dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null || true)"
  [[ "$status" == "install ok installed" ]]
}

corebrum_synapse_menu_ros_ready() {
  local distro
  if [[ "${COREBRUM_SYNAPSE_STUB:-0}" == 1 ]]; then
    [[ "${COREBRUM_SYNAPSE_ROS:-0}" == 1 ]]
    return
  fi
  distro="$(corebrum_synapse_menu_distro)" || return 1
  corebrum_synapse_menu_pkg_installed "ros-${distro}-ros-base"
}

corebrum_synapse_menu_ready() {
  if [[ "${COREBRUM_SYNAPSE_STUB:-0}" == 1 ]]; then
    [[ "${COREBRUM_SYNAPSE_READY:-0}" == 1 ]]
    return
  fi
  [[ -x /usr/local/bin/synapse && -f "${HOME}/.synapse/config.json" ]]
}

corebrum_synapse_menu_entry_name() {
  if corebrum_synapse_menu_ready; then
    printf 'Corebrum Synapse\n'
  else
    printf 'Corebrum Synapse%s\n' "$COREBRUM_SYNAPSE_INSTALL_MARK"
  fi
}

corebrum_synapse_menu_data_dir() {
  local root="${XDG_RUNTIME_DIR:-/tmp/corebrum-launcher-${UID}}"
  printf '%s\n' "${root}/corebrum"
}

corebrum_synapse_menu_refresh() {
  local dir dest name
  dir="$(corebrum_synapse_menu_data_dir)/applications"
  dest="${dir}/corebrum-synapse.desktop"
  mkdir -p "$dir"
  if ! corebrum_synapse_menu_ros_ready; then
    rm -f "$dest"
    corebrum_synapse_menu_clear_actions "$dir"
    return 0
  fi
  name="$(corebrum_synapse_menu_entry_name)"
  cat >"$dest" <<EOF
[Desktop Entry]
Type=Application
Name=${name}
GenericName=${name}
Comment=Corebrum Synapse robot tools on this machine's ROS graph
Exec=/usr/local/bin/corebrum-synapse-menu open
Icon=/usr/share/corebrum/icon.png
Terminal=false
Categories=Science;Development;
StartupNotify=false
EOF
  corebrum_synapse_menu_write_actions "$dir"
}

corebrum_synapse_menu_terminal() {
  local script="$1"
  if [[ "${COREBRUM_SYNAPSE_STUB:-0}" == 1 ]]; then
    printf '%s\n' "$script"
    return 0
  fi
  exec /usr/local/bin/corebrum-terminal bash --login -c "$script"
}

corebrum_synapse_menu_actions() {
  cat <<'EOF'
arc-connect|Cloud: Connect
arc-disconnect|Cloud: Disconnect
arc-sign-in|Cloud: Sign in
camera-start-realsense|Camera: Start RealSense
camera-stop-realsense|Camera: Stop RealSense
camera-start-2d|Camera: Start 2D
camera-stop-2d|Camera: Stop 2D
motors-start|Motors: Start
motors-stop|Motors: Stop
eyes-start|Eyes: Start
eyes-stop|Eyes: Stop
stack-real|Stack: Real robot
stack-sim-amr|Stack: Sim AMR
stack-sim-arm|Stack: Sim arm
stack-stop|Stack: Stop
mode-real|Mode: Real
mode-sim|Mode: Sim
status|Status
doctor|Doctor
agents-connect|Agents: Connect installed CLIs
EOF
}

corebrum_synapse_menu_labels() {
  local slug label
  while IFS='|' read -r slug label; do
    [[ -n "$slug" ]] || continue
    printf '%s\n' "$label"
  done < <(corebrum_synapse_menu_actions)
}

corebrum_synapse_menu_clear_actions() {
  local dir="$1" file
  shopt -s nullglob
  for file in "${dir}"/corebrum-synapse-action-*.desktop "${dir}"/corebrum-agenticros-action-*.desktop; do
    rm -f "$file"
  done
  shopt -u nullglob
  rm -f "${dir}/corebrum-agenticros.desktop"
}

corebrum_synapse_menu_write_actions() {
  local dir="$1" slug label
  corebrum_synapse_menu_clear_actions "$dir"
  corebrum_synapse_menu_ready || return 0
  while IFS='|' read -r slug label; do
    [[ "$slug" =~ ^[a-z0-9-]+$ ]] || corebrum_synapse_menu_die "invalid action id: ${slug}"
    cat >"${dir}/corebrum-synapse-action-${slug}.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=${label}
GenericName=${label}
Keywords=${slug};${label};
Comment=Corebrum Synapse
Exec=/usr/local/bin/corebrum-synapse-menu launch ${slug}
Icon=/usr/share/corebrum/icon.png
Terminal=false
Categories=Science;Development;
StartupNotify=false
NoDisplay=true
EOF
  done < <(corebrum_synapse_menu_actions)
}

corebrum_synapse_menu_run() {
  local choice="$1"
  case "$choice" in
    "Cloud: Connect")
      if [[ "${COREBRUM_SYNAPSE_STUB:-0}" == 1 ]]; then
        printf 'synapse connect\n'
        return 0
      fi
      if /usr/local/bin/synapse connect; then
        notify-send "Corebrum Synapse" "Connected to Corebrum Cloud"
      else
        notify-send "Corebrum Synapse" "Could not connect to Corebrum Cloud"
      fi
      ;;
    "Cloud: Disconnect")
      if [[ "${COREBRUM_SYNAPSE_STUB:-0}" == 1 ]]; then
        printf 'synapse disconnect\n'
        return 0
      fi
      if /usr/local/bin/synapse disconnect; then
        notify-send "Corebrum Synapse" "Disconnected from Corebrum Cloud"
      else
        notify-send "Corebrum Synapse" "Could not disconnect from Corebrum Cloud"
      fi
      ;;
    "Cloud: Sign in")
      corebrum_synapse_menu_terminal "synapse login"
      ;;
    "Camera: Start RealSense")
      corebrum_synapse_menu_terminal "synapse start realsense"
      ;;
    "Camera: Stop RealSense")
      corebrum_synapse_menu_terminal "synapse stop realsense"
      ;;
    "Camera: Start 2D")
      corebrum_synapse_menu_terminal "synapse start camera"
      ;;
    "Camera: Stop 2D")
      corebrum_synapse_menu_terminal "synapse stop camera"
      ;;
    "Motors: Start")
      corebrum_synapse_menu_terminal "synapse start motors"
      ;;
    "Motors: Stop")
      corebrum_synapse_menu_terminal "synapse stop motors"
      ;;
    "Eyes: Start")
      corebrum_synapse_menu_terminal "synapse eyes"
      ;;
    "Eyes: Stop")
      corebrum_synapse_menu_terminal "synapse stop eyes"
      ;;
    "Stack: Real robot")
      corebrum_synapse_menu_terminal "synapse up real"
      ;;
    "Stack: Sim AMR")
      corebrum_synapse_menu_terminal "synapse up sim-amr"
      ;;
    "Stack: Sim arm")
      corebrum_synapse_menu_terminal "synapse up sim-arm"
      ;;
    "Stack: Stop")
      corebrum_synapse_menu_terminal "synapse down"
      ;;
    "Mode: Real")
      if [[ "${COREBRUM_SYNAPSE_STUB:-0}" == 1 ]]; then
        printf 'synapse mode real\n'
        return 0
      fi
      if /usr/local/bin/synapse mode real; then
        notify-send "Corebrum Synapse" "Mode is real"
      else
        notify-send "Corebrum Synapse" "Could not switch to real"
      fi
      ;;
    "Mode: Sim")
      if [[ "${COREBRUM_SYNAPSE_STUB:-0}" == 1 ]]; then
        printf 'synapse mode sim\n'
        return 0
      fi
      if /usr/local/bin/synapse mode sim; then
        notify-send "Corebrum Synapse" "Mode is sim"
      else
        notify-send "Corebrum Synapse" "Could not switch to sim"
      fi
      ;;
    "Status")
      corebrum_synapse_menu_terminal "synapse status"
      ;;
    "Doctor")
      corebrum_synapse_menu_terminal "synapse doctor"
      ;;
    "Agents: Connect installed CLIs")
      corebrum_synapse_menu_terminal "synapse mcp setup --installed"
      ;;
    *)
      corebrum_synapse_menu_die "unknown Corebrum Synapse menu choice"
      ;;
  esac
}

corebrum_synapse_menu_open_tools() {
  local choice=""
  if [[ "${COREBRUM_SYNAPSE_STUB:-0}" == 1 ]]; then
    if [[ -n "${COREBRUM_SYNAPSE_CHOICE:-}" ]]; then
      corebrum_synapse_menu_run "$COREBRUM_SYNAPSE_CHOICE"
      return 0
    fi
    corebrum_synapse_menu_labels
    return 0
  fi
  choice="$(corebrum_synapse_menu_labels | fuzzel \
    --config /etc/corebrum/fuzzel/fuzzel.ini \
    --dmenu \
    --prompt 'Corebrum Synapse  ' \
    --width 48 \
    --lines 16)" || return 0
  [[ -n "$choice" ]] || return 0
  corebrum_synapse_menu_run "$choice"
}

corebrum_synapse_menu_open() {
  local script="/usr/local/lib/corebrum/synapse-install.sh"
  if ! corebrum_synapse_menu_ros_ready; then
    corebrum_synapse_menu_die "ROS 2 is not installed"
  fi
  if corebrum_synapse_menu_ready; then
    corebrum_synapse_menu_open_tools
    return 0
  fi
  if [[ "${COREBRUM_SYNAPSE_STUB:-0}" != 1 && ! -x "$script" ]]; then
    corebrum_synapse_menu_die "the Corebrum Synapse installer is not installed"
  fi
  corebrum_synapse_menu_terminal "$(cat <<EOF
set +e
${script}
ec=\$?
if [ "\$ec" -eq 0 ]; then
  /usr/local/bin/synapse init --yes
  ec=\$?
fi
printf '\\n'
if [ "\$ec" -eq 0 ]; then
  printf '%s\\n' "Corebrum Synapse is installed. Press Super+Space and choose Corebrum Synapse."
else
  printf 'Install failed (%s).\\n' "\$ec"
fi
read -r -p 'Press Enter to close. '
EOF
)"
}

corebrum_synapse_menu_launch_id() {
  local id="$1" slug label
  [[ "$id" =~ ^[a-z0-9-]+$ ]] || corebrum_synapse_menu_die "invalid Corebrum Synapse action"
  if ! corebrum_synapse_menu_ready; then
    corebrum_synapse_menu_open
    return 0
  fi
  while IFS='|' read -r slug label; do
    if [[ "$slug" == "$id" ]]; then
      corebrum_synapse_menu_run "$label"
      return 0
    fi
  done < <(corebrum_synapse_menu_actions)
  corebrum_synapse_menu_die "unknown Corebrum Synapse action ${id}"
}

usage() {
  cat <<'EOF'
Usage: corebrum-synapse-menu refresh|open|launch ID|entry-name|labels|data-dir
EOF
}

cmd="${1:-}"
case "$cmd" in
  refresh) corebrum_synapse_menu_refresh ;;
  launch) corebrum_synapse_menu_launch_id "${2:-}" ;;
  open) corebrum_synapse_menu_open ;;
  entry-name) corebrum_synapse_menu_entry_name ;;
  labels) corebrum_synapse_menu_labels ;;
  data-dir) corebrum_synapse_menu_data_dir ;;
  -h | --help | help) usage ;;
  *)
    usage >&2
    exit 1
    ;;
esac
