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

if ! corebrum_supported_ubuntu "noble"; then
  echo "FAIL: noble should be supported" >&2
  exit 1
fi
if ! corebrum_supported_ubuntu "resolute"; then
  echo "FAIL: resolute should be supported" >&2
  exit 1
fi
if ! corebrum_supported_release ubuntu noble 24.04; then
  echo "FAIL: Ubuntu 24.04 noble should be supported" >&2
  exit 1
fi
if ! corebrum_supported_release ubuntu resolute 26.04; then
  echo "FAIL: Ubuntu 26.04 resolute should be supported" >&2
  exit 1
fi
if corebrum_supported_release ubuntu noble 26.04; then
  echo "FAIL: noble must stay on VERSION_ID 24.04" >&2
  exit 1
fi
if corebrum_supported_release ubuntu resolute 24.04; then
  echo "FAIL: resolute must stay on VERSION_ID 26.04" >&2
  exit 1
fi
if corebrum_supported_release debian noble 24.04; then
  echo "FAIL: a non-Ubuntu noble release should be rejected" >&2
  exit 1
fi
if [[ "$(corebrum_lock_package noble)" != "gtklock" ]]; then
  echo "FAIL: noble should lock with gtklock" >&2
  exit 1
fi
if [[ "$(corebrum_lock_package resolute)" != "gtklock" ]]; then
  echo "FAIL: resolute should lock with gtklock" >&2
  exit 1
fi
if ! corebrum_gtklock_from_source noble; then
  echo "FAIL: noble should build gtklock" >&2
  exit 1
fi
if corebrum_gtklock_from_source resolute; then
  echo "FAIL: resolute should use the archive gtklock" >&2
  exit 1
fi
if corebrum_lock_package jammy; then
  echo "FAIL: jammy should not select a lock program" >&2
  exit 1
fi
# shellcheck source=../../scripts/desktop/corebrum-lock.sh
source "${ROOT}/scripts/desktop/corebrum-lock.sh"
if [[ "$(corebrum_lock_package noble)" != "gtklock" || "$(corebrum_lock_package resolute)" != "gtklock" ]]; then
  echo "FAIL: the lock command does not use gtklock on noble and resolute" >&2
  exit 1
fi
if corebrum_supported_ubuntu "jammy"; then
  echo "FAIL: jammy should be rejected" >&2
  exit 1
fi
if corebrum_supported_ubuntu "24.04"; then
  echo "FAIL: a version number should be rejected" >&2
  exit 1
fi
jammy="$(corebrum_read_os_release_field "${ROOT}/tests/unit/fixtures/os-release-2204" VERSION_CODENAME)"
if corebrum_supported_ubuntu "$jammy"; then
  echo "FAIL: fixture jammy should be rejected" >&2
  exit 1
fi

if ! corebrum_supported_arch "x86_64"; then
  echo "FAIL: x86_64 should be supported" >&2
  exit 1
fi
if ! corebrum_supported_arch "aarch64"; then
  echo "FAIL: aarch64 should be supported" >&2
  exit 1
fi
if corebrum_supported_arch "armv7l"; then
  echo "FAIL: armv7l should be rejected" >&2
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
