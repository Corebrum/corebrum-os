#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=../../scripts/lib/log.sh
source "${ROOT}/scripts/lib/log.sh"
# shellcheck source=../../scripts/lib/grid.sh
source "${ROOT}/scripts/lib/grid.sh"

assert_eq() {
  local got="$1"
  local expected="$2"
  local message="$3"
  if [[ "$got" != "$expected" ]]; then
    printf 'FAIL: %s (got %q expected %q)\n' "$message" "$got" "$expected" >&2
    exit 1
  fi
}

labels=()
commands=()
corebrum_load_tiles "${ROOT}/tests/unit/fixtures/tiles-ok.conf" labels commands
assert_eq "${#labels[@]}" "3" "tile count"
assert_eq "${labels[0]}" "Terminal" "first label"
assert_eq "${commands[2]}" "firefox --new-window" "command keeps spaces"

if (corebrum_load_tiles "${ROOT}/tests/unit/fixtures/tiles-bad.conf" labels commands >/dev/null 2>&1); then
  echo "FAIL: invalid tile manifest was accepted" >&2
  exit 1
fi

list="$(COREBRUM_GRID_MANIFEST="${ROOT}/apps/dashboard/tiles.conf" "${ROOT}/scripts/desktop/corebrum-grid.sh" --list)"
if ! grep -qx 'Terminal' <<<"$list"; then
  echo "FAIL: shipped grid did not list Terminal" >&2
  exit 1
fi
if ! grep -qx 'Files' <<<"$list"; then
  echo "FAIL: shipped grid did not list Files" >&2
  exit 1
fi

echo "ok: grid"
