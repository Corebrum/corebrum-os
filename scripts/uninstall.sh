#!/usr/bin/env bash
# Remove Corebrum-owned desktop configuration. Does not remove Ubuntu packages.
set -euo pipefail

COREBRUM_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export COREBRUM_ROOT

# shellcheck source=lib/log.sh
source "${COREBRUM_ROOT}/scripts/lib/log.sh"
# shellcheck source=lib/system.sh
source "${COREBRUM_ROOT}/scripts/lib/system.sh"

DRY_RUN=0
PROFILE=""
export DRY_RUN

usage() {
  cat <<'EOF'
Usage: scripts/uninstall.sh [--profile base|desktop] [--dry-run]

  --profile desktop   Disable greetd and remove Corebrum desktop files
  --profile base      Refuses. The base profile is ordinary Ubuntu packages
  --dry-run           Print intended actions without changing the system
  -h, --help          Show this help

With no profile, this command refuses to remove packages.
Desktop uninstall does not run apt remove. Reboot after a real uninstall.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile)
      [[ $# -ge 2 ]] || {
        echo "uninstall: --profile requires a value" >&2
        exit 1
      }
      PROFILE="$2"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      echo "uninstall: unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

export DRY_RUN

case "$PROFILE" in
  "")
    echo "Phase 1 does not install a removable Corebrum package. Refusing to remove Ubuntu base packages." >&2
    exit 1
    ;;
  base)
    echo "The base profile does not install a removable Corebrum package. Refusing to remove Ubuntu base packages." >&2
    exit 1
    ;;
  desktop)
    # shellcheck source=lib/desktop.sh
    source "${COREBRUM_ROOT}/scripts/lib/desktop.sh"
    corebrum_uninstall_desktop
    ;;
  *)
    echo "uninstall: profile '${PROFILE}' is not available (expected: base or desktop)" >&2
    exit 1
    ;;
esac
