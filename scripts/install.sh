#!/usr/bin/env bash
# Corebrum OS installer. Phase 1 implements the base profile only.
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

DRY_RUN=0
ENABLE_SSH=0
PROFILE=""
export DRY_RUN ENABLE_SSH

usage() {
  cat <<'EOF'
Usage: scripts/install.sh --profile base [--dry-run] [--enable-ssh]

  --profile base   Install the Ubuntu Server foundation (only profile in this phase)
  --dry-run        Print intended actions without changing the system
  --enable-ssh     Also install and enable OpenSSH server
  -h, --help       Show this help

A real install must be run as root. --dry-run may be run as a normal user.
Desktop and robotics profiles are not implemented yet.
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

[[ -n "$PROFILE" ]] || corebrum_die "missing --profile (expected: base)"

case "$PROFILE" in
  base) ;;
  *)
    corebrum_die "profile '${PROFILE}' is not available in this phase (only: base)"
    ;;
esac

if [[ "$DRY_RUN" -eq 0 && "$(id -u)" -ne 0 ]]; then
  corebrum_die "a real install requires root; re-run with sudo or pass --dry-run"
fi

trap 'corebrum_log "failed at ${BASH_SOURCE[0]}:${LINENO}"' ERR

if [[ "$DRY_RUN" -eq 0 ]]; then
  corebrum_init_log
else
  corebrum_log "dry-run: no packages, services, or files will be changed"
fi

corebrum_preflight

# shellcheck source=phases/01-base.sh
source "${COREBRUM_ROOT}/scripts/phases/01-base.sh"
corebrum_phase_base
