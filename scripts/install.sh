#!/usr/bin/env bash
# Corebrum OS installer. Profiles: base (Phase 1), desktop (Phases 2 and 3), ros (Phase 5).
# The product command is scripts/corebrum.sh.
set -eEuo pipefail

COREBRUM_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export COREBRUM_ROOT

# shellcheck source=lib/log.sh
source "${COREBRUM_ROOT}/scripts/lib/log.sh"
# shellcheck source=lib/manifest.sh
source "${COREBRUM_ROOT}/scripts/lib/manifest.sh"
# shellcheck source=lib/preflight.sh
source "${COREBRUM_ROOT}/scripts/lib/preflight.sh"
# shellcheck source=lib/apt.sh
source "${COREBRUM_ROOT}/scripts/lib/apt.sh"
# shellcheck source=lib/system.sh
source "${COREBRUM_ROOT}/scripts/lib/system.sh"
# shellcheck source=lib/cli.sh
source "${COREBRUM_ROOT}/scripts/lib/cli.sh"

DRY_RUN=0
ENABLE_SSH=0
PROFILE=""
export DRY_RUN ENABLE_SSH

usage() {
  cat <<'EOF'
Usage: scripts/install.sh --profile base|desktop|ros [--dry-run] [--enable-ssh]

  --profile base      Install the Ubuntu Server foundation
  --profile desktop   Install the base profile, the Sway desktop, and workstation services
  --profile ros       Install the base profile, ROS 2, and the Zenoh router
  --dry-run           Print intended actions without changing the system
  --enable-ssh        Also install and enable OpenSSH server
  -h, --help          Show this help

A real install must be run as root. --dry-run may be run as a normal user.
The product command is: corebrum install base|desktop|ros
The installer accepts Ubuntu Server 24.04 (VERSION_CODENAME=noble) and 26.04
(VERSION_CODENAME=resolute) on x86_64 and aarch64. Other releases are rejected.
Sway comes from the Ubuntu archive. The installer does not add a Hyprland PPA.
Workstation services come from the Ubuntu archive. The ros profile adds the
official ROS 2 apt repository and does not install the desktop. It installs
ROS 2 Jazzy on Ubuntu 24.04 and ROS 2 Lyrical Luth on Ubuntu 26.04.
The installer does not edit existing Netplan files or run netplan apply.
The desktop profile installs Node.js 26.x, npm, and pnpm with nvm under
/usr/local/nvm. It does not write ~/.nvm or ~/.bashrc.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile)
      [[ $# -ge 2 ]] || corebrum_die "--profile requires a value"
      PROFILE="$2"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --enable-ssh)
      ENABLE_SSH=1
      shift
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      corebrum_die "unknown argument: $1"
      ;;
  esac
done

export DRY_RUN ENABLE_SSH

[[ -n "$PROFILE" ]] || corebrum_die "missing --profile (expected: base, desktop, or ros)"

case "$PROFILE" in
  base | desktop | ros) ;;
  *)
    corebrum_die "profile '${PROFILE}' is not available (expected: base, desktop, or ros)"
    ;;
esac

if [[ "$DRY_RUN" -eq 0 && "$(id -u)" -ne 0 ]]; then
  corebrum_die "a real install requires root; re-run with sudo or pass --dry-run"
fi

trap 'corebrum_log "failed at ${BASH_SOURCE[0]}:${LINENO}: ${BASH_COMMAND}"' ERR

if [[ "$DRY_RUN" -eq 1 ]]; then
  corebrum_log "dry-run: no packages, services, or files will be changed"
elif [[ "$PROFILE" == "base" || "$PROFILE" == "ros" ]]; then
  corebrum_init_log
fi

corebrum_preflight
corebrum_install_command

if [[ "$PROFILE" == "desktop" ]]; then
  # shellcheck source=lib/desktop.sh
  source "${COREBRUM_ROOT}/scripts/lib/desktop.sh"
  corebrum_desktop_plan
  corebrum_desktop_disk_check
  if [[ "$DRY_RUN" -eq 0 ]]; then
    corebrum_init_log
  fi
fi

# shellcheck source=phases/01-base.sh
source "${COREBRUM_ROOT}/scripts/phases/01-base.sh"
corebrum_phase_base

if [[ "$PROFILE" == "desktop" ]]; then
  # shellcheck source=phases/02-desktop.sh
  source "${COREBRUM_ROOT}/scripts/phases/02-desktop.sh"
  corebrum_phase_desktop
  # shellcheck source=phases/03-services.sh
  source "${COREBRUM_ROOT}/scripts/phases/03-services.sh"
  corebrum_phase_services
fi

if [[ "$PROFILE" == "ros" ]]; then
  # shellcheck source=phases/05-ros.sh
  source "${COREBRUM_ROOT}/scripts/phases/05-ros.sh"
  corebrum_phase_ros
fi
