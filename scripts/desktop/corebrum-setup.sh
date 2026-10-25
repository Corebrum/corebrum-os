#!/usr/bin/env bash
# First-login setup. ROS 2, then RealSense, then AgenticROS, then AI agents.
# Skip or exit is available on every step. Exit remembers that choice.
set -euo pipefail

corebrum_setup_die() {
  printf 'corebrum-setup: %s\n' "$1" >&2
  exit 1
}

corebrum_setup_state_file() {
  local root="${XDG_STATE_HOME:-${HOME}/.local/state}"
  printf '%s\n' "${root}/corebrum/setup-done"
}

corebrum_setup_mark_done() {
  local file
  file="$(corebrum_setup_state_file)"
  mkdir -p "$(dirname "$file")"
  printf 'done\n' >"$file"
}

corebrum_setup_say() {
  printf '%s\n' "$1"
}

corebrum_setup_next_answer() {
  local answer
  if [[ "${COREBRUM_SETUP_STUB:-0}" == 1 ]]; then
    # The prompt runs inside a command substitution. A shell variable updated
    # there is discarded, so the queued answers stay on this file descriptor.
    if ! IFS= read -r answer <&3; then
      corebrum_setup_die "no answer left"
    fi
    printf '%s\n' "$answer"
    return 0
  fi
  if ! read -r -p '> ' answer; then
    exit 0
  fi
  printf '%s\n' "$answer"
}

corebrum_setup_normalize() {
  local key="${1,,}"
  key="${key//[[:space:]]/}"
  case "$key" in
    i | install) printf 'i\n' ;;
    s | skip | done) printf 's\n' ;;
    x | exit | q | quit) printf 'x\n' ;;
    r | ros) printf 'r\n' ;;
    *) printf '%s\n' "$key" ;;
  esac
}

corebrum_setup_ask() {
  printf '\n'
  printf '%s\n' "$@"
  printf '\n'
}

corebrum_setup_choice() {
  corebrum_setup_normalize "$(corebrum_setup_next_answer)"
}

corebrum_setup_quit() {
  corebrum_setup_say "Setup closed. Super+Space can install ROS 2, RealSense, AgenticROS, and AI Agents later."
  corebrum_setup_mark_done
  exit 0
}

corebrum_setup_finish() {
  corebrum_setup_say "Setup is finished. Super+Space can install or open any of these later."
  corebrum_setup_mark_done
  if [[ "${COREBRUM_SETUP_STUB:-0}" != 1 ]]; then
    read -r -p 'Press Enter to close. ' _ || true
  fi
  exit 0
}

corebrum_setup_run() {
  if [[ "${COREBRUM_SETUP_STUB:-0}" == 1 ]]; then
    printf 'run:'
    printf ' %s' "$@"
    printf '\n'
    return 0
  fi
  "$@"
}

corebrum_setup_run_shell() {
  local script="$1"
  if [[ "${COREBRUM_SETUP_STUB:-0}" == 1 ]]; then
    printf 'run: %s\n' "$script"
    return 0
  fi
  bash -c "$script"
}

corebrum_setup_ros_distro() {
  local distro="" codename
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

corebrum_setup_pkg_installed() {
  local status
  status="$(dpkg-query -W -f='${Status}' "$1" 2>/dev/null || true)"
  [[ "$status" == "install ok installed" ]]
}

corebrum_setup_ros_ready() {
  local distro
  if [[ "${COREBRUM_SETUP_STUB:-0}" == 1 ]]; then
    [[ "${COREBRUM_SETUP_ROS:-0}" == 1 ]]
    return
  fi
  distro="$(corebrum_setup_ros_distro)" || return 1
  corebrum_setup_pkg_installed "ros-${distro}-ros-base" \
    && [[ -f /etc/apt/sources.list.d/ros2.sources ]]
}

corebrum_setup_realsense_ready() {
  local name menu
  if [[ "${COREBRUM_SETUP_STUB:-0}" == 1 ]]; then
    [[ "${COREBRUM_SETUP_REALSENSE:-0}" == 1 ]]
    return
  fi
  menu=/usr/local/bin/corebrum-realsense-menu
  [[ -x "$menu" ]] || return 1
  name="$("$menu" entry-name 2>/dev/null || true)"
  [[ -n "$name" && "$name" != *install* ]]
}

corebrum_setup_agenticros_ready() {
  if [[ "${COREBRUM_SETUP_STUB:-0}" == 1 ]]; then
    [[ "${COREBRUM_SETUP_AGENTICROS:-0}" == 1 ]]
    return
  fi
  [[ -x /usr/local/bin/agenticros && -f "${HOME}/.agenticros/config.json" ]]
}

corebrum_setup_agents_ready() {
  local id label ready binary any=0 rows
  rows="$(corebrum_setup_agent_rows)" || return 1
  [[ -n "$rows" ]] || return 1
  while IFS=$'\t' read -r id label ready binary; do
    [[ -n "$id" ]] || continue
    any=1
    [[ "$ready" == 1 ]] || return 1
  done <<<"$rows"
  [[ "$any" == 1 ]]
}

# ROS 2, RealSense, AgenticROS, and every catalog agent. A missing piece
# still opens the wizard. A finished set writes the marker and stays closed.
corebrum_setup_complete() {
  corebrum_setup_ros_ready || return 1
  corebrum_setup_realsense_ready || return 1
  corebrum_setup_agenticros_ready || return 1
  corebrum_setup_agents_ready
}

corebrum_setup_login() {
  local marker
  marker="$(corebrum_setup_state_file)"
  if [[ -f "$marker" ]]; then
    exit 0
  fi
  if corebrum_setup_complete; then
    corebrum_setup_mark_done
    exit 0
  fi
  if [[ "${COREBRUM_SETUP_STUB:-0}" == 1 ]]; then
    printf '%s\n' "open-wizard"
    exit 0
  fi
  exec /usr/local/bin/corebrum-terminal --class corebrum-setup /usr/local/bin/corebrum-setup
}

corebrum_setup_install_ros() {
  if corebrum_setup_run sudo corebrum install ros; then
    COREBRUM_SETUP_ROS=1
    return 0
  fi
  return 1
}

corebrum_setup_install_realsense() {
  local script="/usr/local/lib/corebrum/realsense-install.sh"
  if [[ "${COREBRUM_SETUP_STUB:-0}" != 1 && ! -x "$script" ]]; then
    corebrum_setup_say "The RealSense installer is not installed."
    return 1
  fi
  if corebrum_setup_run sudo "$script"; then
    COREBRUM_SETUP_REALSENSE=1
    return 0
  fi
  return 1
}

corebrum_setup_install_agenticros() {
  local script="/usr/local/lib/corebrum/agenticros-install.sh"
  if [[ "${COREBRUM_SETUP_STUB:-0}" != 1 && ! -x "$script" ]]; then
    corebrum_setup_say "The AgenticROS installer is not installed."
    return 1
  fi
  if ! corebrum_setup_run "$script"; then
    return 1
  fi
  if ! corebrum_setup_run /usr/local/bin/agenticros init --yes; then
    return 1
  fi
  COREBRUM_SETUP_AGENTICROS=1
  COREBRUM_AGENTICROS_READY=1
  return 0
}

corebrum_setup_failed() {
  corebrum_setup_say "Install failed. You can try again, skip this step, or exit."
}

corebrum_setup_step_ros() {
  local choice
  if corebrum_setup_ros_ready; then
    corebrum_setup_say "ROS 2 is already installed."
    return 0
  fi
  while true; do
    corebrum_setup_ask \
      "Step 1 of 4 — ROS 2" \
      "ROS 2 is the robot middleware. RealSense and AgenticROS need it." \
      "  i  Install" \
      "  s  Skip" \
      "  x  Exit"
    choice="$(corebrum_setup_choice)"
    case "$choice" in
      i)
        corebrum_setup_install_ros && return 0
        corebrum_setup_failed
        ;;
      s) return 0 ;;
      x) corebrum_setup_quit ;;
      *) corebrum_setup_say "Press i, s, or x." ;;
    esac
  done
}

corebrum_setup_step_realsense() {
  local choice
  if corebrum_setup_realsense_ready; then
    corebrum_setup_say "RealSense is already installed."
    return 0
  fi
  while true; do
    if ! corebrum_setup_ros_ready; then
      corebrum_setup_ask \
        "Step 2 of 4 — RealSense" \
        "RealSense needs ROS 2, and ROS 2 is not installed yet." \
        "  r  Install ROS 2 now" \
        "  s  Skip" \
        "  x  Exit"
    choice="$(corebrum_setup_choice)"
      case "$choice" in
        r)
          corebrum_setup_install_ros && continue
          corebrum_setup_failed
          ;;
        s) return 0 ;;
        x) corebrum_setup_quit ;;
        *) corebrum_setup_say "RealSense needs ROS 2. Press r to install ROS 2, s to skip, or x to exit." ;;
      esac
      continue
    fi
    corebrum_setup_ask \
      "Step 2 of 4 — RealSense" \
      "Installs the RealSense camera SDK, the ROS camera driver, and pyrealsense2." \
      "  i  Install" \
      "  s  Skip" \
      "  x  Exit"
    choice="$(corebrum_setup_choice)"
    case "$choice" in
      i)
        corebrum_setup_install_realsense && return 0
        corebrum_setup_failed
        ;;
      s) return 0 ;;
      x) corebrum_setup_quit ;;
      *) corebrum_setup_say "Press i, s, or x." ;;
    esac
  done
}

corebrum_setup_step_agenticros() {
  local choice
  if corebrum_setup_agenticros_ready; then
    corebrum_setup_say "AgenticROS is already installed."
    return 0
  fi
  while true; do
    if ! corebrum_setup_ros_ready; then
      corebrum_setup_ask \
        "Step 3 of 4 — AgenticROS" \
        "AgenticROS needs ROS 2, and ROS 2 is not installed yet." \
        "  r  Install ROS 2 now" \
        "  s  Skip" \
        "  x  Exit"
    choice="$(corebrum_setup_choice)"
      case "$choice" in
        r)
          corebrum_setup_install_ros && continue
          corebrum_setup_failed
          ;;
        s) return 0 ;;
        x) corebrum_setup_quit ;;
        *) corebrum_setup_say "AgenticROS needs ROS 2. Press r to install ROS 2, s to skip, or x to exit." ;;
      esac
      continue
    fi
    corebrum_setup_ask \
      "Step 3 of 4 — AgenticROS" \
      "Builds AgenticROS, connects it to this machine's Zenoh ROS graph, and registers agents that are already installed." \
      "  i  Install" \
      "  s  Skip" \
      "  x  Exit"
    choice="$(corebrum_setup_choice)"
    case "$choice" in
      i)
        corebrum_setup_install_agenticros && return 0
        corebrum_setup_failed
        ;;
      s) return 0 ;;
      x) corebrum_setup_quit ;;
      *) corebrum_setup_say "Press i, s, or x." ;;
    esac
  done
}

corebrum_setup_agents_menu() {
  if [[ -n "${COREBRUM_SETUP_AGENTS_MENU:-}" ]]; then
    printf '%s\n' "$COREBRUM_SETUP_AGENTS_MENU"
    return 0
  fi
  if [[ -x /usr/local/bin/corebrum-agents-menu ]]; then
    printf '%s\n' /usr/local/bin/corebrum-agents-menu
    return 0
  fi
  printf '%s\n' "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/corebrum-agents-menu.sh"
}

corebrum_setup_agent_rows() {
  local menu
  menu="$(corebrum_setup_agents_menu)"
  if [[ "${COREBRUM_SETUP_STUB:-0}" == 1 ]]; then
    COREBRUM_AGENTS_STUB=1 "$menu" rows
  else
    "$menu" rows
  fi
}

corebrum_setup_install_agent() {
  local id="$1" binary="$2" menu action
  menu="$(corebrum_setup_agents_menu)"
  if [[ "${COREBRUM_SETUP_STUB:-0}" == 1 ]]; then
    action="$(COREBRUM_AGENTS_STUB=1 "$menu" command "$id")"
    corebrum_setup_run_shell "$action"
    COREBRUM_AGENTS_INSTALLED="${COREBRUM_AGENTS_INSTALLED:-} ${binary}"
    export COREBRUM_AGENTS_INSTALLED
    if [[ "${COREBRUM_SETUP_AGENTICROS:-0}" == 1 ]]; then
      COREBRUM_AGENTS_STUB=1 COREBRUM_AGENTICROS_READY=1 "$menu" couple "$id" || true
    fi
    return 0
  fi
  action="$("$menu" command "$id")"
  export PATH="${HOME}/.local/bin:${PATH}"
  if corebrum_setup_run_shell "$action"; then
    "$menu" couple "$id" || true
    return 0
  fi
  return 1
}

corebrum_setup_step_agents() {
  local choice id label ready binary n
  local -a ids=() labels=() readies=() binaries=()
  if corebrum_setup_agents_ready; then
    corebrum_setup_say "AI agents are already installed."
    corebrum_setup_finish
  fi
  while true; do
    ids=()
    labels=()
    readies=()
    binaries=()
    while IFS=$'\t' read -r id label ready binary; do
      [[ -n "$id" ]] || continue
      ids+=("$id")
      labels+=("$label")
      readies+=("$ready")
      binaries+=("$binary")
    done < <(corebrum_setup_agent_rows)
    [[ "${#ids[@]}" -gt 0 ]] || corebrum_setup_die "agent list is empty"
    printf '\n%s\n' "Step 4 of 4 — AI Agents"
    printf '%s\n' "Install one or more. Skip when you are done. The first launch of an agent still asks you to sign in."
    printf '\n'
    n=1
    for id in "${!ids[@]}"; do
      if [[ "${readies[$id]}" == 1 ]]; then
        printf '  %s  %s  (installed)\n' "$n" "${labels[$id]}"
      else
        printf '  %s  %s\n' "$n" "${labels[$id]}"
      fi
      n=$((n + 1))
    done
    printf '  s  Skip\n'
    printf '  x  Exit\n'
    printf '\n'
    choice="$(corebrum_setup_normalize "$(corebrum_setup_next_answer)")"
    case "$choice" in
      s) corebrum_setup_finish ;;
      x) corebrum_setup_quit ;;
    esac
    if [[ "$choice" =~ ^[0-9]+$ ]] && ((choice >= 1 && choice <= ${#ids[@]})); then
      n=$((choice - 1))
      if [[ "${readies[$n]}" == 1 ]]; then
        corebrum_setup_say "${labels[$n]} is already installed."
        continue
      fi
      if corebrum_setup_install_agent "${ids[$n]}" "${binaries[$n]}"; then
        corebrum_setup_say "${labels[$n]} is installed."
      else
        corebrum_setup_failed
      fi
      continue
    fi
    corebrum_setup_say "Choose a number, s, or x."
  done
}

corebrum_setup_main() {
  local marker
  if [[ "${1:-}" == "login" ]]; then
    corebrum_setup_login
  fi
  marker="$(corebrum_setup_state_file)"
  if [[ "${1:-}" != "again" && -f "$marker" ]]; then
    exit 0
  fi
  if [[ "${1:-}" != "again" ]] && corebrum_setup_complete; then
    corebrum_setup_mark_done
    exit 0
  fi
  if [[ "${COREBRUM_SETUP_STUB:-0}" == 1 ]]; then
    exec 3<<<"${COREBRUM_SETUP_ANSWERS:-}"
  fi
  corebrum_setup_say "Corebrum setup"
  corebrum_setup_say "Four steps, in order. RealSense and AgenticROS need ROS 2. You can skip or exit at any step."
  corebrum_setup_step_ros
  corebrum_setup_step_realsense
  corebrum_setup_step_agenticros
  corebrum_setup_step_agents
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  corebrum_setup_main "$@"
fi
