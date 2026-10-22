#!/usr/bin/env bash
# Super+Space ROS entry. Install ROS 2, or open the tool submenu.
set -euo pipefail

COREBRUM_ROS_INSTALL_MARK='   install'
COREBRUM_ROS_TOOLS_DEFAULT="/etc/corebrum/ros-tools.conf"

corebrum_ros_menu_die() {
  printf 'corebrum-ros-menu: %s\n' "$1" >&2
  exit 1
}

corebrum_ros_menu_distro() {
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

corebrum_ros_menu_pkg_installed() {
  local pkg="$1" status
  if [[ "${COREBRUM_ROS_MENU_STUB:-0}" == 1 ]]; then
    [[ " ${COREBRUM_ROS_MENU_INSTALLED:-} " == *" ${pkg} "* ]]
    return
  fi
  status="$(dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null || true)"
  [[ "$status" == "install ok installed" ]]
}

corebrum_ros_menu_base_pkg() {
  local distro
  distro="$(corebrum_ros_menu_distro)" || corebrum_ros_menu_die "this Ubuntu release has no ROS 2 menu"
  printf 'ros-%s-ros-base\n' "$distro"
}

corebrum_ros_menu_catalog() {
  if [[ -n "${COREBRUM_ROS_TOOLS_FILE:-}" ]]; then
    printf '%s\n' "$COREBRUM_ROS_TOOLS_FILE"
  else
    printf '%s\n' "$COREBRUM_ROS_TOOLS_DEFAULT"
  fi
}

corebrum_ros_menu_load() {
  local file line id label suffix command distro
  local -a fields=()
  file="$(corebrum_ros_menu_catalog)"
  [[ -f "$file" ]] || corebrum_ros_menu_die "missing tool list ${file}"
  distro="$(corebrum_ros_menu_distro)" || corebrum_ros_menu_die "this Ubuntu release has no ROS 2 menu"
  ROS_MENU_IDS=()
  ROS_MENU_LABELS=()
  ROS_MENU_PKGS=()
  ROS_MENU_CMDS=()
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%%#*}"
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"
    [[ -z "$line" ]] && continue
    IFS='|' read -r -a fields <<<"$line"
    if [[ "${#fields[@]}" -ne 4 ]]; then
      corebrum_ros_menu_die "invalid tool line: ${line}"
    fi
    id="${fields[0]}"
    label="${fields[1]}"
    suffix="${fields[2]}"
    command="${fields[3]}"
    [[ "$id" =~ ^[a-z0-9-]+$ ]] || corebrum_ros_menu_die "invalid tool id: ${id}"
    [[ "$suffix" =~ ^[a-z0-9][a-z0-9+.-]*$ ]] || corebrum_ros_menu_die "invalid package suffix: ${suffix}"
    [[ "$command" =~ ^[A-Za-z0-9_.:/=[:space:]-]+$ ]] || corebrum_ros_menu_die "invalid launch command for ${id}"
    [[ -n "$label" ]] || corebrum_ros_menu_die "missing label for ${id}"
    ROS_MENU_IDS+=("$id")
    ROS_MENU_LABELS+=("$label")
    ROS_MENU_PKGS+=("ros-${distro}-${suffix}")
    ROS_MENU_CMDS+=("$command")
  done <"$file"
  [[ "${#ROS_MENU_IDS[@]}" -gt 0 ]] || corebrum_ros_menu_die "tool list is empty: ${file}"
}

corebrum_ros_menu_entry_name() {
  local base
  base="$(corebrum_ros_menu_base_pkg)"
  if corebrum_ros_menu_pkg_installed "$base"; then
    printf 'ROS\n'
  else
    printf 'ROS 2%s\n' "$COREBRUM_ROS_INSTALL_MARK"
  fi
}

corebrum_ros_menu_line() {
  local pkg="$1" label="$2"
  if corebrum_ros_menu_pkg_installed "$pkg"; then
    printf '%s\n' "$label"
  else
    printf '%s%s\n' "$label" "$COREBRUM_ROS_INSTALL_MARK"
  fi
}

corebrum_ros_menu_labels() {
  local i
  corebrum_ros_menu_load
  for i in "${!ROS_MENU_IDS[@]}"; do
    corebrum_ros_menu_line "${ROS_MENU_PKGS[$i]}" "${ROS_MENU_LABELS[$i]}"
  done
}

corebrum_ros_menu_data_dir() {
  local root="${XDG_RUNTIME_DIR:-/tmp/corebrum-launcher-${UID}}"
  printf '%s\n' "${root}/corebrum"
}

corebrum_ros_menu_refresh() {
  local dir name
  dir="$(corebrum_ros_menu_data_dir)/applications"
  name="$(corebrum_ros_menu_entry_name)"
  mkdir -p "$dir"
  cat >"${dir}/corebrum-ros.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=${name}
GenericName=${name}
Comment=ROS 2 and robotics tools
Exec=/usr/local/bin/corebrum-ros-menu open
Icon=applications-science
Terminal=false
Categories=Science;Development;
StartupNotify=false
EOF
}

corebrum_ros_menu_terminal() {
  local script="$1"
  if [[ "${COREBRUM_ROS_MENU_STUB:-0}" == 1 ]]; then
    printf '%s\n' "$script"
    return 0
  fi
  exec /usr/local/bin/corebrum-terminal bash -c "$script"
}

corebrum_ros_menu_hold() {
  local action="$1" success="$2"
  corebrum_ros_menu_terminal "$(cat <<EOF
set +e
${action}
ec=\$?
set -e
printf '\\n'
if [ "\$ec" -eq 0 ]; then
  printf '%s\\n' "${success}"
else
  printf 'Install failed (%s).\\n' "\$ec"
fi
read -r -p 'Press Enter to close. '
EOF
)"
}

corebrum_ros_menu_install_base() {
  corebrum_ros_menu_hold \
    "sudo corebrum install ros" \
    "ROS 2 is installed. Press Super+Space and choose ROS."
}

corebrum_ros_menu_install_pkg() {
  local pkg="$1"
  [[ "$pkg" =~ ^ros-[a-z]+-[a-z0-9][a-z0-9+.-]*$ ]] || corebrum_ros_menu_die "refusing package ${pkg}"
  corebrum_ros_menu_hold \
    "sudo apt-get update && sudo apt-get install -y --no-install-recommends ${pkg}" \
    "${pkg} is installed. Press Super+Space, choose ROS, and select it again to launch."
}

corebrum_ros_menu_launch() {
  local command="$1"
  local -a argv=()
  read -r -a argv <<<"$command"
  [[ "${#argv[@]}" -gt 0 ]] || corebrum_ros_menu_die "missing launch command"
  if [[ "${COREBRUM_ROS_MENU_STUB:-0}" == 1 ]]; then
    printf '%s\n' "${argv[*]}"
    return 0
  fi
  if [[ ! -x /usr/local/lib/corebrum/with-ros.sh ]]; then
    corebrum_ros_menu_die "the ROS environment is not installed"
  fi
  # The GUI is the window. Sourcing ROS here avoids a terminal beside it.
  exec /usr/local/lib/corebrum/with-ros.sh "${argv[@]}"
}

corebrum_ros_menu_open_tools() {
  local choice="" i line
  local -a lines=()
  corebrum_ros_menu_load
  for i in "${!ROS_MENU_IDS[@]}"; do
    line="$(corebrum_ros_menu_line "${ROS_MENU_PKGS[$i]}" "${ROS_MENU_LABELS[$i]}")"
    lines+=("$line")
  done
  if [[ "${COREBRUM_ROS_MENU_STUB:-0}" == 1 ]]; then
    printf '%s\n' "${lines[@]}"
    return 0
  fi
  choice="$(printf '%s\n' "${lines[@]}" | fuzzel \
    --config /etc/corebrum/fuzzel/fuzzel.ini \
    --dmenu \
    --prompt 'ROS  ' \
    --width 48 \
    --lines 8)" || return 0
  [[ -n "$choice" ]] || return 0
  for i in "${!lines[@]}"; do
    if [[ "$choice" == "${lines[$i]}" ]]; then
      if corebrum_ros_menu_pkg_installed "${ROS_MENU_PKGS[$i]}"; then
        corebrum_ros_menu_launch "${ROS_MENU_CMDS[$i]}"
      else
        corebrum_ros_menu_install_pkg "${ROS_MENU_PKGS[$i]}"
      fi
      return 0
    fi
  done
  corebrum_ros_menu_die "unknown ROS menu choice"
}

corebrum_ros_menu_open() {
  local base
  base="$(corebrum_ros_menu_base_pkg)"
  if corebrum_ros_menu_pkg_installed "$base"; then
    corebrum_ros_menu_open_tools
  else
    corebrum_ros_menu_install_base
  fi
}

usage() {
  cat <<'EOF'
Usage: corebrum-ros-menu refresh|open|entry-name|labels|data-dir
EOF
}

cmd="${1:-}"
case "$cmd" in
  refresh) corebrum_ros_menu_refresh ;;
  open) corebrum_ros_menu_open ;;
  entry-name) corebrum_ros_menu_entry_name ;;
  labels) corebrum_ros_menu_labels ;;
  data-dir) corebrum_ros_menu_data_dir ;;
  -h | --help | help) usage ;;
  *)
    usage >&2
    exit 1
    ;;
esac
