#!/usr/bin/env bash
# Corebrum command. Profiles: base (headless), desktop, and ros.
set -euo pipefail

source_path="$(readlink -f "${BASH_SOURCE[0]}")"
COREBRUM_ROOT="$(cd "$(dirname "$source_path")/.." && pwd)"
export COREBRUM_ROOT

# shellcheck source=lib/log.sh
source "${COREBRUM_ROOT}/scripts/lib/log.sh"
# shellcheck source=lib/cli.sh
source "${COREBRUM_ROOT}/scripts/lib/cli.sh"
# shellcheck source=lib/ros.sh
source "${COREBRUM_ROOT}/scripts/lib/ros.sh"

usage() {
  cat <<'EOF'
Usage: corebrum <command> [arguments]

  version                  Print the Corebrum version
  status                   Show which profiles are installed
  doctor                   Check an install and print the next action
  config                   Show configuration paths
  install <profile>        Install base (headless), desktop, or ros
  uninstall <profile>      Remove Corebrum desktop or ROS files
  ros status|topics|rmw    Inspect ROS 2 or select Zenoh or Fast DDS
  zenoh status|peers       Inspect the Zenoh router
  help                     Show this help

install profiles are base, headless, desktop, and ros. headless is the base profile.
The ros profile does not install the desktop.
Optional install flag: --enable-ssh. --dry-run prints the plan only.

The command does not write ~/.config. A real install does not edit existing
Netplan files. After a failure, read /var/log/corebrum/install-latest.log
and run corebrum doctor.
EOF
}

command_name="${1:-}"
if [[ $# -gt 0 ]]; then
  shift
fi

case "$command_name" in
  version)
    corebrum_cmd_version
    ;;
  status)
    corebrum_cmd_status
    ;;
  doctor)
    corebrum_cmd_doctor
    ;;
  config)
    corebrum_cmd_config
    ;;
  install)
    corebrum_cmd_install "$@"
    ;;
  uninstall)
    corebrum_cmd_uninstall "$@"
    ;;
  ros)
    corebrum_cmd_ros "$@"
    ;;
  zenoh)
    corebrum_cmd_zenoh "$@"
    ;;
  "" | -h | --help | help)
    usage
    ;;
  *)
    corebrum_die "unknown command: ${command_name}"
    ;;
esac
