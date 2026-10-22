#!/usr/bin/env bash
# Phase 5 ROS 2 Jazzy and Zenoh helpers. Source this file; do not execute it.
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  echo "source scripts/lib/ros.sh from another script" >&2
  exit 1
fi

# shellcheck source=log.sh
source "${COREBRUM_ROOT}/scripts/lib/log.sh"
# shellcheck source=system.sh
source "${COREBRUM_ROOT}/scripts/lib/system.sh"
# shellcheck source=files.sh
source "${COREBRUM_ROOT}/scripts/lib/files.sh"
# shellcheck source=manifest.sh
source "${COREBRUM_ROOT}/scripts/lib/manifest.sh"

# Open Robotics key shipped in ros2-apt-source 1.3.0 noble.
COREBRUM_ROS_KEY_FINGERPRINT="C1CF6E31E6BADE8868B172B4F42ED6FBAB17C654"
COREBRUM_ROS_APT_URL="https://github.com/ros-infrastructure/ros-apt-source/releases/download/1.3.0/ros2-apt-source_1.3.0.noble_all.deb"
COREBRUM_ROS_APT_SHA256="f31d84adf5054c7d60ded0e82c0f776a77ea33af53d08f40b9ad7c94cca55296"
COREBRUM_ROS_KEYRING="/usr/share/keyrings/ros2-archive-keyring.gpg"
COREBRUM_ROS_SOURCES="/etc/apt/sources.list.d/ros2.sources"
COREBRUM_ROS_RMW="/etc/corebrum/ros/rmw"
COREBRUM_ROS_PROFILE="/etc/profile.d/corebrum-ros.sh"
COREBRUM_ROS_UNIT="corebrum-zenoh-router.service"
COREBRUM_ROS_TILE='ROS|kitty /usr/local/bin/corebrum-ros-shell'

corebrum_ros_require_fingerprint() {
  local key="$1" fingerprint
  [[ -f "$key" ]] || corebrum_die "missing ROS keyring ${key}"
  fingerprint="$(gpg --batch --show-keys --with-colons "$key" | awk -F: '/^fpr:/ { print $10; exit }' || true)"
  if [[ "$fingerprint" != "$COREBRUM_ROS_KEY_FINGERPRINT" ]]; then
    corebrum_die "ROS apt key fingerprint ${fingerprint:-missing} does not match ${COREBRUM_ROS_KEY_FINGERPRINT}"
  fi
}

corebrum_ros_require_suites() {
  local sources="/etc/apt/sources.list.d/ubuntu.sources"
  if [[ ! -f "$sources" ]] || ! grep -q 'noble-updates' "$sources" || ! grep -q 'universe' "$sources"; then
    corebrum_die "Ubuntu sources must include noble-updates and universe before ROS 2. Not editing ${sources}"
  fi
  corebrum_log "Ubuntu sources include noble-updates and universe"
}

corebrum_ros_install_apt_source() {
  local version work status
  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    corebrum_log "dry-run: download ${COREBRUM_ROS_APT_URL}"
    corebrum_log "dry-run: require sha256 ${COREBRUM_ROS_APT_SHA256}"
    corebrum_log "dry-run: require ROS key fingerprint ${COREBRUM_ROS_KEY_FINGERPRINT}"
    corebrum_log "dry-run: dpkg -i ros2-apt-source when it is not already installed"
    corebrum_log "dry-run: require ${COREBRUM_ROS_SOURCES} to point at the ROS apt source"
    return 0
  fi
  version="$(dpkg-query -W -f='${Version}' ros2-apt-source 2>/dev/null || true)"
  if [[ -n "$version" ]]; then
    corebrum_ros_require_fingerprint "$COREBRUM_ROS_KEYRING"
    if [[ ! -L "$COREBRUM_ROS_SOURCES" ]]; then
      corebrum_die "ROS apt source is not linked at ${COREBRUM_ROS_SOURCES}"
    fi
    corebrum_log "ros2-apt-source ${version} is already installed"
    return 0
  fi
  command -v curl >/dev/null 2>&1 || corebrum_die "curl is required to fetch the ROS apt source"
  command -v gpg >/dev/null 2>&1 || corebrum_die "gpg is required to check the ROS apt key"
  work="$(mktemp -d)"
  if ! curl -fsSL -o "${work}/ros2-apt-source.deb" "$COREBRUM_ROS_APT_URL"; then
    rm -rf "$work"
    corebrum_die "could not download the ROS apt source package"
  fi
  if ! echo "${COREBRUM_ROS_APT_SHA256}  ${work}/ros2-apt-source.deb" | sha256sum -c - >/dev/null; then
    rm -rf "$work"
    corebrum_die "ROS apt source package checksum does not match ${COREBRUM_ROS_APT_SHA256}"
  fi
  dpkg-deb -x "${work}/ros2-apt-source.deb" "${work}/root"
  corebrum_ros_require_fingerprint "${work}/root/usr/share/keyrings/ros2-archive-keyring.gpg"
  export DEBIAN_FRONTEND=noninteractive
  corebrum_log "run: dpkg -i ros2-apt-source 1.3.0"
  status=0
  dpkg -i "${work}/ros2-apt-source.deb" || status=$?
  rm -rf "$work"
  [[ "$status" -eq 0 ]] || corebrum_die "dpkg -i ros2-apt-source failed"
  corebrum_ros_require_fingerprint "$COREBRUM_ROS_KEYRING"
  if [[ ! -L "$COREBRUM_ROS_SOURCES" ]]; then
    corebrum_die "ROS apt source is not linked at ${COREBRUM_ROS_SOURCES}"
  fi
}

corebrum_ros_install_rmw_default() {
  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    corebrum_log "dry-run: install ${COREBRUM_ROS_RMW} with rmw_zenoh_cpp when that file is absent"
    return 0
  fi
  if [[ -f "$COREBRUM_ROS_RMW" ]]; then
    corebrum_log "keeping existing ${COREBRUM_ROS_RMW}"
    return 0
  fi
  corebrum_install_file "${COREBRUM_ROOT}/config/ros/rmw" "$COREBRUM_ROS_RMW" 644
}

corebrum_ros_router_count() {
  pgrep -c -x rmw_zenohd 2>/dev/null || true
}

corebrum_ros_require_single_router() {
  local count
  count="$(corebrum_ros_router_count)"
  count="${count:-0}"
  if [[ "$count" -gt 1 ]]; then
    corebrum_die "found ${count} rmw_zenohd processes; refusing a second Zenoh router"
  fi
  if [[ "$count" -eq 1 ]] && ! systemctl is-active --quiet "$COREBRUM_ROS_UNIT"; then
    corebrum_die "rmw_zenohd is running outside ${COREBRUM_ROS_UNIT}; refusing to start another router"
  fi
}

corebrum_ros_enable_router() {
  local state count
  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    corebrum_log "dry-run: systemctl daemon-reload"
    corebrum_log "dry-run: systemctl enable --now ${COREBRUM_ROS_UNIT} when it is not already enabled"
    return 0
  fi
  corebrum_ros_require_single_router
  corebrum_log "run: systemctl daemon-reload"
  systemctl daemon-reload
  state="$(systemctl is-enabled "$COREBRUM_ROS_UNIT" 2>/dev/null || true)"
  if [[ "$state" == "enabled" ]]; then
    corebrum_log "already enabled: ${COREBRUM_ROS_UNIT}"
    systemctl start "$COREBRUM_ROS_UNIT"
  else
    corebrum_state_set_once enabled_zenoh_router 1
    corebrum_log "run: systemctl enable --now ${COREBRUM_ROS_UNIT}"
    systemctl enable --now "$COREBRUM_ROS_UNIT"
  fi
  for _ in $(seq 1 30); do
    count="$(corebrum_ros_router_count)"
    if systemctl is-active --quiet "$COREBRUM_ROS_UNIT" && [[ "${count:-0}" -eq 1 ]]; then
      corebrum_log "Zenoh router is active"
      return 0
    fi
    if [[ "${count:-0}" -gt 1 ]]; then
      corebrum_die "found ${count} rmw_zenohd processes; refusing a second Zenoh router"
    fi
    sleep 0.5
  done
  corebrum_die "Zenoh router did not stay active with one rmw_zenohd process (found ${count:-0}); see journalctl -u ${COREBRUM_ROS_UNIT}"
}

corebrum_ros_init_rosdep() {
  local marker="/etc/ros/rosdep/sources.list.d/20-default.list"
  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    corebrum_log "dry-run: rosdep init when ${marker} is absent"
    corebrum_log "dry-run: not running rosdep update"
    return 0
  fi
  if [[ -f "$marker" ]]; then
    corebrum_log "rosdep already initialized"
    return 0
  fi
  command -v rosdep >/dev/null 2>&1 || corebrum_die "rosdep is not installed"
  corebrum_log "run: rosdep init"
  rosdep init
}

corebrum_ros_install_tile() {
  local tiles="/etc/corebrum/dashboard/tiles.conf"
  if [[ ! -f "$tiles" ]]; then
    corebrum_log "app grid is not installed; not adding a ROS tile"
    return 0
  fi
  if grep -qxF "$COREBRUM_ROS_TILE" "$tiles"; then
    corebrum_log "unchanged: ROS tile in ${tiles}"
    return 0
  fi
  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    corebrum_log "dry-run: append ROS tile to ${tiles}"
    return 0
  fi
  corebrum_backup_file "$tiles"
  printf '%s\n' "$COREBRUM_ROS_TILE" >>"$tiles"
  corebrum_log "appended ROS tile to ${tiles}"
}

corebrum_ros_remove_tile() {
  local tiles="/etc/corebrum/dashboard/tiles.conf" filtered
  if [[ ! -f "$tiles" ]] || ! grep -qxF "$COREBRUM_ROS_TILE" "$tiles"; then
    return 0
  fi
  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    corebrum_log "dry-run: remove ROS tile from ${tiles}"
    return 0
  fi
  corebrum_backup_file "$tiles"
  filtered="$(mktemp)"
  grep -vxF "$COREBRUM_ROS_TILE" "$tiles" >"$filtered" || true
  mv "$filtered" "$tiles"
  corebrum_log "removed ROS tile from ${tiles}"
}

corebrum_phase_ros() {
  local manifest="${COREBRUM_ROOT}/manifests/packages/ros.txt"
  local -a packages=()
  corebrum_ros_require_suites
  corebrum_log "not changing existing Netplan files or running netplan apply"
  corebrum_log "not running apt upgrade"
  corebrum_ros_install_apt_source
  corebrum_load_manifest "$manifest" packages
  corebrum_apt_install "${packages[@]}"
  corebrum_ros_install_rmw_default
  corebrum_install_file "${COREBRUM_ROOT}/config/ros/profile.sh" "$COREBRUM_ROS_PROFILE" 644
  corebrum_install_file "${COREBRUM_ROOT}/scripts/ros/with-ros.sh" /usr/local/lib/corebrum/with-ros.sh 755
  corebrum_install_file "${COREBRUM_ROOT}/scripts/ros/zenoh-router.sh" /usr/local/lib/corebrum/zenoh-router.sh 755
  corebrum_install_file "${COREBRUM_ROOT}/scripts/ros/corebrum-ros-shell.sh" /usr/local/bin/corebrum-ros-shell 755
  corebrum_install_file \
    "${COREBRUM_ROOT}/config/systemd/corebrum-zenoh-router.service" \
    "/etc/systemd/system/${COREBRUM_ROS_UNIT}" \
    644
  if [[ -e /usr/local/bin/corebrum-session ]]; then
    corebrum_install_file \
      "${COREBRUM_ROOT}/scripts/desktop/corebrum-session.sh" \
      /usr/local/bin/corebrum-session \
      755
  fi
  corebrum_ros_init_rosdep
  corebrum_ros_enable_router
  corebrum_ros_install_tile
  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    corebrum_log "dry-run: exercise ROS topics, services, and actions through the Zenoh router, then restart it"
    corebrum_log "ros profile dry-run complete"
    return 0
  fi
  bash "${COREBRUM_ROOT}/scripts/validate/ros-graph.sh"
  corebrum_log "ros profile install complete"
}

corebrum_uninstall_ros() {
  local path
  if [[ "${DRY_RUN:-0}" -eq 0 && "$(id -u)" -ne 0 ]]; then
    corebrum_die "ros uninstall requires root; pass --dry-run to preview"
  fi
  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    corebrum_log "dry-run: systemctl disable --now ${COREBRUM_ROS_UNIT}"
    corebrum_log "dry-run: remove the Corebrum Zenoh unit, profile script, and /etc/corebrum/ros"
    corebrum_log "dry-run: leave ros2-apt-source and the ROS packages installed"
    corebrum_ros_remove_tile
    corebrum_log "ros uninstall dry-run complete"
    return 0
  fi
  systemctl disable --now "$COREBRUM_ROS_UNIT" >/dev/null 2>&1 || corebrum_log "could not disable ${COREBRUM_ROS_UNIT}"
  for path in \
    "/etc/systemd/system/${COREBRUM_ROS_UNIT}" \
    "$COREBRUM_ROS_PROFILE" \
    /usr/local/lib/corebrum/with-ros.sh \
    /usr/local/lib/corebrum/zenoh-router.sh \
    /usr/local/bin/corebrum-ros-shell \
    "$COREBRUM_ROS_RMW"
  do
    if [[ -e "$path" ]]; then
      corebrum_backup_file "$path"
      rm -f "$path"
      corebrum_log "removed ${path}"
    fi
  done
  rmdir /etc/corebrum/ros 2>/dev/null || true
  systemctl daemon-reload || true
  corebrum_ros_remove_tile
  corebrum_log "ros uninstall complete; ROS packages and ros2-apt-source were left installed"
}

corebrum_cmd_ros() {
  local sub="${1:-}"
  case "$sub" in
    status)
      corebrum_cmd_ros_status
      ;;
    topics)
      corebrum_cmd_ros_topics
      ;;
    rmw)
      corebrum_cmd_ros_rmw "${2:-}"
      ;;
    "" | -h | --help | help)
      cat <<'EOF'
Usage: corebrum ros status|topics|rmw

  status          Show the ROS distro, RMW, and Zenoh router
  topics          List ROS topics with the selected RMW
  rmw zenoh       Select rmw_zenoh_cpp for new login shells
  rmw fastrtps    Select the Fast DDS fallback for new login shells

rmw writes /etc/corebrum/ros/rmw and needs root. It does not stop the router.
EOF
      [[ -n "$sub" ]] || return 1
      ;;
    *)
      corebrum_die "unknown ros command: ${sub}"
      ;;
  esac
}

corebrum_cmd_ros_status() {
  local rmw="unset" router="inactive" version=""
  if [[ -f /opt/ros/jazzy/setup.bash ]]; then
    printf 'ros distro: jazzy\n'
  else
    printf 'ros distro: not installed\n'
  fi
  if [[ -f "$COREBRUM_ROS_RMW" ]]; then
    rmw="$(tr -d '[:space:]' <"$COREBRUM_ROS_RMW")"
  fi
  printf 'rmw: %s\n' "$rmw"
  printf 'domain: %s\n' "${ROS_DOMAIN_ID:-0}"
  router="$(systemctl is-active "$COREBRUM_ROS_UNIT" 2>/dev/null || true)"
  printf 'zenoh router: %s\n' "${router:-inactive}"
  version="$(dpkg-query -W -f='${Version}' ros-jazzy-rmw-zenoh-cpp 2>/dev/null || true)"
  if [[ -n "$version" ]]; then
    printf 'rmw_zenoh_cpp: %s\n' "$version"
  fi
}

corebrum_cmd_ros_topics() {
  local with="${COREBRUM_ROOT}/scripts/ros/with-ros.sh"
  [[ -x "$with" && -f /opt/ros/jazzy/setup.bash ]] || corebrum_die "ROS 2 Jazzy is not installed"
  "$with" timeout 15 ros2 topic list
}

corebrum_cmd_ros_rmw() {
  local choice="$1" src
  case "$choice" in
    zenoh)
      src="${COREBRUM_ROOT}/config/ros/rmw"
      ;;
    fastrtps | dds)
      src="${COREBRUM_ROOT}/config/ros/rmw-fastrtps"
      ;;
    *)
      corebrum_die "expected: corebrum ros rmw zenoh|fastrtps"
      ;;
  esac
  if [[ "$(id -u)" -ne 0 ]]; then
    corebrum_die "selecting an RMW requires root"
  fi
  corebrum_install_file "$src" "$COREBRUM_ROS_RMW" 644
  corebrum_log "open a new login shell to use the selected RMW; the Zenoh router is left running"
}

corebrum_cmd_zenoh() {
  local sub="${1:-}"
  case "$sub" in
    status)
      corebrum_cmd_zenoh_status
      ;;
    peers)
      corebrum_cmd_zenoh_peers
      ;;
    "" | -h | --help | help)
      cat <<'EOF'
Usage: corebrum zenoh status|peers

  status    Show the Corebrum Zenoh router service
  peers     Show the router listen address and this machine's IPv4 addresses

Local ROS sessions connect to tcp/localhost:7447. Another machine connects
its sessions to tcp/<this-address>:7447. See docs/installation/ros.md.
EOF
      [[ -n "$sub" ]] || return 1
      ;;
    *)
      corebrum_die "unknown zenoh command: ${sub}"
      ;;
  esac
}

corebrum_cmd_zenoh_status() {
  local active enabled count
  active="$(systemctl is-active "$COREBRUM_ROS_UNIT" 2>/dev/null || true)"
  enabled="$(systemctl is-enabled "$COREBRUM_ROS_UNIT" 2>/dev/null || true)"
  count="$(corebrum_ros_router_count)"
  printf 'unit: %s\n' "$COREBRUM_ROS_UNIT"
  printf 'active: %s\n' "${active:-inactive}"
  printf 'enabled: %s\n' "${enabled:-disabled}"
  printf 'rmw_zenohd processes: %s\n' "${count:-0}"
  printf 'listen: tcp/[::]:7447\n'
  printf 'local sessions connect: tcp/localhost:7447\n'
}

corebrum_cmd_zenoh_peers() {
  corebrum_cmd_zenoh_status
  printf 'addresses:\n'
  ip -4 -o addr show scope global | awk '{ print "  " $2 " " $4 }'
  printf 'A second machine connects its Zenoh sessions to tcp/<one of these addresses>:7447.\n'
}
