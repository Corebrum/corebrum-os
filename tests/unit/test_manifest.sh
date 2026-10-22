#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=../../scripts/lib/log.sh
source "${ROOT}/scripts/lib/log.sh"
# shellcheck source=../../scripts/lib/manifest.sh
source "${ROOT}/scripts/lib/manifest.sh"

assert_eq() {
  local got="$1"
  local expected="$2"
  local message="$3"
  if [[ "$got" != "$expected" ]]; then
    printf 'FAIL: %s (got %q expected %q)\n' "$message" "$got" "$expected" >&2
    exit 1
  fi
}

if corebrum_valid_package_name "not a package"; then
  echo "FAIL: invalid package name accepted" >&2
  exit 1
fi
if ! corebrum_valid_package_name "openssh-server"; then
  echo "FAIL: openssh-server rejected" >&2
  exit 1
fi

packages=()
corebrum_load_manifest "${ROOT}/tests/unit/fixtures/packages-ok.txt" packages
assert_eq "${#packages[@]}" "2" "package count"
assert_eq "${packages[0]}" "ca-certificates" "first package"
assert_eq "${packages[1]}" "curl" "second package"

if (corebrum_load_manifest "${ROOT}/tests/unit/fixtures/packages-bad.txt" packages >/dev/null 2>&1); then
  echo "FAIL: invalid manifest was accepted" >&2
  exit 1
fi

echo "ok: manifest"
