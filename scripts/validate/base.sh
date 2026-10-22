#!/usr/bin/env bash
# Validate a completed base-profile install. Safe to run as a normal user.
set -euo pipefail

COREBRUM_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=../lib/log.sh
source "${COREBRUM_ROOT}/scripts/lib/log.sh"
# shellcheck source=../lib/manifest.sh
source "${COREBRUM_ROOT}/scripts/lib/manifest.sh"

DRY_RUN=0
failed=0
packages=()

corebrum_load_manifest "${COREBRUM_ROOT}/manifests/packages/base.txt" packages

for pkg in "${packages[@]}"; do
  status="$(dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null || true)"
  if [[ "$status" == "install ok installed" ]]; then
    corebrum_log "ok: ${pkg}"
  else
    corebrum_log "missing: ${pkg}"
    failed=1
  fi
done

if locale -a | grep -Eiq '^en_US\.(utf8|utf-8)$'; then
  corebrum_log "ok: locale en_US.UTF-8"
else
  corebrum_log "missing: locale en_US.UTF-8"
  failed=1
fi

if ip -4 route show default 2>/dev/null | grep -q .; then
  corebrum_log "ok: default route"
else
  corebrum_log "missing: default IPv4 route"
  failed=1
fi

if [[ "$failed" -eq 0 ]]; then
  corebrum_log "base validation passed"
else
  corebrum_log "base validation failed"
fi

exit "$failed"
