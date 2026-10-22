#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=../../scripts/lib/log.sh
source "${ROOT}/scripts/lib/log.sh"
# shellcheck source=../../scripts/lib/preflight.sh
source "${ROOT}/scripts/lib/preflight.sh"

assert_eq() {
  local got="$1"
  local expected="$2"
  local message="$3"
  if [[ "$got" != "$expected" ]]; then
    printf 'FAIL: %s (got %q expected %q)\n' "$message" "$got" "$expected" >&2
    exit 1
  fi
}

quoted="$(corebrum_read_os_release_field "${ROOT}/tests/unit/fixtures/os-release-2404" VERSION_ID)"
assert_eq "$quoted" "24.04" "quoted VERSION_ID"
unquoted="$(corebrum_read_os_release_field "${ROOT}/tests/unit/fixtures/os-release-unquoted" VERSION_ID)"
assert_eq "$unquoted" "24.04" "unquoted VERSION_ID"

if ! corebrum_supported_ubuntu "24.04"; then
  echo "FAIL: 24.04 should be supported" >&2
  exit 1
fi
if corebrum_supported_ubuntu "22.04"; then
  echo "FAIL: 22.04 should be rejected" >&2
  exit 1
fi
jammy="$(corebrum_read_os_release_field "${ROOT}/tests/unit/fixtures/os-release-2204" VERSION_ID)"
if corebrum_supported_ubuntu "$jammy"; then
  echo "FAIL: fixture 22.04 should be rejected" >&2
  exit 1
fi

if ! corebrum_supported_arch "x86_64"; then
  echo "FAIL: x86_64 should be supported" >&2
  exit 1
fi
if corebrum_supported_arch "aarch64"; then
  echo "FAIL: aarch64 should be rejected in this phase" >&2
  exit 1
fi

if ! corebrum_disk_is_sufficient 8388608 8388608; then
  echo "FAIL: exact minimum disk should pass" >&2
  exit 1
fi
if corebrum_disk_is_sufficient 8388607 8388608; then
  echo "FAIL: disk below minimum should fail" >&2
  exit 1
fi

echo "ok: preflight"
