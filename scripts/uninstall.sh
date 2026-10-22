#!/usr/bin/env bash
# Phase 1 has no removable product package. This command refuses to uninstall Ubuntu.
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: scripts/uninstall.sh

Phase 1 does not install a removable Corebrum package.
This command refuses to remove Ubuntu base packages.
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

echo "Phase 1 does not install a removable Corebrum package. Refusing to remove Ubuntu base packages." >&2
exit 1
