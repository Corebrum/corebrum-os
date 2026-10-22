#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
INSTALL="${ROOT}/scripts/install.sh"

if ! "$INSTALL" --help >/dev/null; then
  echo "FAIL: --help should succeed" >&2
  exit 1
fi

if "$INSTALL" --profile desktop --dry-run >/dev/null 2>&1; then
  echo "FAIL: desktop profile should be rejected" >&2
  exit 1
fi

if "$INSTALL" >/dev/null 2>&1; then
  echo "FAIL: missing --profile should be rejected" >&2
  exit 1
fi

if "${ROOT}/scripts/uninstall.sh" --help >/dev/null; then
  :
else
  echo "FAIL: uninstall --help should succeed" >&2
  exit 1
fi

if "${ROOT}/scripts/uninstall.sh" >/dev/null 2>&1; then
  echo "FAIL: uninstall should refuse to remove packages" >&2
  exit 1
fi

echo "ok: cli"
