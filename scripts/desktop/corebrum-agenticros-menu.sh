#!/usr/bin/env bash
# Super+Space AgenticROS entry. Hidden until ROS is installed.
set -euo pipefail

COREBRUM_AGENTICROS_INSTALL_MARK='   install'

corebrum_agenticros_menu_die() {
  printf 'corebrum-agenticros-menu: %s\n' "$1" >&2
  exit 1
}

corebrum_agenticros_menu_distro() {
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

corebrum_agenticros_menu_pkg_installed() {
  local pkg="$1" status
  status="$(dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null || true)"
  [[ "$status" == "install ok installed" ]]
}

corebrum_agenticros_menu_ros_ready() {
  local distro
  if [[ "${COREBRUM_AGENTICROS_STUB:-0}" == 1 ]]; then
    [[ "${COREBRUM_AGENTICROS_ROS:-0}" == 1 ]]
    return
  fi
  distro="$(corebrum_agenticros_menu_distro)" || return 1
  corebrum_agenticros_menu_pkg_installed "ros-${distro}-ros-base"
}

corebrum_agenticros_menu_ready() {
  if [[ "${COREBRUM_AGENTICROS_STUB:-0}" == 1 ]]; then
    [[ "${COREBRUM_AGENTICROS_READY:-0}" == 1 ]]
    return
  fi
  [[ -x /usr/local/bin/agenticros && -f "${HOME}/.agenticros/config.json" ]]
}

corebrum_agenticros_menu_entry_name() {
  if corebrum_agenticros_menu_ready; then
    printf 'AgenticROS\n'
  else
    printf 'AgenticROS%s\n' "$COREBRUM_AGENTICROS_INSTALL_MARK"
  fi
}

corebrum_agenticros_menu_data_dir() {
  local root="${XDG_RUNTIME_DIR:-/tmp/corebrum-launcher-${UID}}"
  printf '%s\n' "${root}/corebrum"
}

corebrum_agenticros_menu_refresh() {
  local dir dest name
  dir="$(corebrum_agenticros_menu_data_dir)/applications"
  dest="${dir}/corebrum-agenticros.desktop"
  mkdir -p "$dir"
  if ! corebrum_agenticros_menu_ros_ready; then
    rm -f "$dest"
    return 0
  fi
  name="$(corebrum_agenticros_menu_entry_name)"
  cat >"$dest" <<EOF
[Desktop Entry]
Type=Application
Name=${name}
GenericName=${name}
Comment=AgenticROS robot tools on this machine's ROS graph
Exec=/usr/local/bin/corebrum-agenticros-menu open
Icon=applications-science
Terminal=false
Categories=Science;Development;
StartupNotify=false
EOF
}

corebrum_agenticros_menu_terminal() {
  local script="$1"
  if [[ "${COREBRUM_AGENTICROS_STUB:-0}" == 1 ]]; then
    printf '%s\n' "$script"
    return 0
  fi
  exec /usr/local/bin/corebrum-terminal bash --login -c "$script"
}

corebrum_agenticros_menu_labels() {
  cat <<'EOF'
ARC: Connect
ARC: Disconnect
ARC: Sign in
Camera: Start RealSense
Camera: Stop RealSense
Camera: Start 2D
Camera: Stop 2D
Motors: Start
Motors: Stop
Eyes: Start
Eyes: Stop
Stack: Real robot
Stack: Sim AMR
Stack: Sim arm
Stack: Stop
Mode: Real
Mode: Sim
Status
Doctor
Agents: Connect installed CLIs
EOF
}

corebrum_agenticros_menu_run() {
  local choice="$1"
  case "$choice" in
    "ARC: Connect")
      if [[ "${COREBRUM_AGENTICROS_STUB:-0}" == 1 ]]; then
        printf 'agenticros connect\n'
        return 0
      fi
      if /usr/local/bin/agenticros connect; then
        notify-send "AgenticROS" "Connected to ARC"
      else
        notify-send "AgenticROS" "Could not connect to ARC"
      fi
      ;;
    "ARC: Disconnect")
      if [[ "${COREBRUM_AGENTICROS_STUB:-0}" == 1 ]]; then
        printf 'agenticros disconnect\n'
        return 0
      fi
      if /usr/local/bin/agenticros disconnect; then
        notify-send "AgenticROS" "Disconnected from ARC"
      else
        notify-send "AgenticROS" "Could not disconnect from ARC"
      fi
      ;;
    "ARC: Sign in")
      corebrum_agenticros_menu_terminal "agenticros login"
      ;;
    "Camera: Start RealSense")
      corebrum_agenticros_menu_terminal "agenticros start realsense"
      ;;
    "Camera: Stop RealSense")
      corebrum_agenticros_menu_terminal "agenticros stop realsense"
      ;;
    "Camera: Start 2D")
      corebrum_agenticros_menu_terminal "agenticros start camera"
      ;;
    "Camera: Stop 2D")
      corebrum_agenticros_menu_terminal "agenticros stop camera"
      ;;
    "Motors: Start")
      corebrum_agenticros_menu_terminal "agenticros start motors"
      ;;
    "Motors: Stop")
      corebrum_agenticros_menu_terminal "agenticros stop motors"
      ;;
    "Eyes: Start")
      corebrum_agenticros_menu_terminal "agenticros eyes"
      ;;
    "Eyes: Stop")
      corebrum_agenticros_menu_terminal "agenticros stop eyes"
      ;;
    "Stack: Real robot")
      corebrum_agenticros_menu_terminal "agenticros up real"
      ;;
    "Stack: Sim AMR")
      corebrum_agenticros_menu_terminal "agenticros up sim-amr"
      ;;
    "Stack: Sim arm")
      corebrum_agenticros_menu_terminal "agenticros up sim-arm"
      ;;
    "Stack: Stop")
      corebrum_agenticros_menu_terminal "agenticros down"
      ;;
    "Mode: Real")
      if [[ "${COREBRUM_AGENTICROS_STUB:-0}" == 1 ]]; then
        printf 'agenticros mode real\n'
        return 0
      fi
      if /usr/local/bin/agenticros mode real; then
        notify-send "AgenticROS" "Mode is real"
      else
        notify-send "AgenticROS" "Could not switch to real"
      fi
      ;;
    "Mode: Sim")
      if [[ "${COREBRUM_AGENTICROS_STUB:-0}" == 1 ]]; then
        printf 'agenticros mode sim\n'
        return 0
      fi
      if /usr/local/bin/agenticros mode sim; then
        notify-send "AgenticROS" "Mode is sim"
      else
        notify-send "AgenticROS" "Could not switch to sim"
      fi
      ;;
    "Status")
      corebrum_agenticros_menu_terminal "agenticros status"
      ;;
    "Doctor")
      corebrum_agenticros_menu_terminal "agenticros doctor"
      ;;
    "Agents: Connect installed CLIs")
      corebrum_agenticros_menu_terminal "agenticros mcp setup --installed"
      ;;
    *)
      corebrum_agenticros_menu_die "unknown AgenticROS menu choice"
      ;;
  esac
}

corebrum_agenticros_menu_open_tools() {
  local choice=""
  if [[ "${COREBRUM_AGENTICROS_STUB:-0}" == 1 ]]; then
    if [[ -n "${COREBRUM_AGENTICROS_CHOICE:-}" ]]; then
      corebrum_agenticros_menu_run "$COREBRUM_AGENTICROS_CHOICE"
      return 0
    fi
    corebrum_agenticros_menu_labels
    return 0
  fi
  choice="$(corebrum_agenticros_menu_labels | fuzzel \
    --config /etc/corebrum/fuzzel/fuzzel.ini \
    --dmenu \
    --prompt 'AgenticROS  ' \
    --width 48 \
    --lines 16)" || return 0
  [[ -n "$choice" ]] || return 0
  corebrum_agenticros_menu_run "$choice"
}

corebrum_agenticros_menu_open() {
  local script="/usr/local/lib/corebrum/agenticros-install.sh"
  if ! corebrum_agenticros_menu_ros_ready; then
    corebrum_agenticros_menu_die "ROS 2 is not installed"
  fi
  if corebrum_agenticros_menu_ready; then
    corebrum_agenticros_menu_open_tools
    return 0
  fi
  if [[ "${COREBRUM_AGENTICROS_STUB:-0}" != 1 && ! -x "$script" ]]; then
    corebrum_agenticros_menu_die "the AgenticROS installer is not installed"
  fi
  corebrum_agenticros_menu_terminal "$(cat <<EOF
set +e
${script}
ec=\$?
if [ "\$ec" -eq 0 ]; then
  /usr/local/bin/agenticros init --yes
  ec=\$?
fi
printf '\\n'
if [ "\$ec" -eq 0 ]; then
  printf '%s\\n' "AgenticROS is installed. Press Super+Space and choose AgenticROS."
else
  printf 'Install failed (%s).\\n' "\$ec"
fi
read -r -p 'Press Enter to close. '
EOF
)"
}

usage() {
  cat <<'EOF'
Usage: corebrum-agenticros-menu refresh|open|entry-name|labels|data-dir
EOF
}

cmd="${1:-}"
case "$cmd" in
  refresh) corebrum_agenticros_menu_refresh ;;
  open) corebrum_agenticros_menu_open ;;
  entry-name) corebrum_agenticros_menu_entry_name ;;
  labels) corebrum_agenticros_menu_labels ;;
  data-dir) corebrum_agenticros_menu_data_dir ;;
  -h | --help | help) usage ;;
  *)
    usage >&2
    exit 1
    ;;
esac
