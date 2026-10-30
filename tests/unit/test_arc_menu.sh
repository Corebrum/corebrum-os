#!/usr/bin/env bash
# Corebrum Cloud is a Super+Space row that opens the site in Firefox.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
menu="${ROOT}/scripts/desktop/corebrum-arc-menu.sh"
launcher="${ROOT}/scripts/desktop/corebrum-launcher.sh"
desktop_lib="${ROOT}/scripts/lib/desktop.sh"
fail=0

assert_grep() {
  local pattern="$1" file="$2" message="$3"
  if ! grep -qE "$pattern" "$file"; then
    echo "FAIL: ${message}" >&2
    fail=1
  fi
}

assert_grep 'corebrum-arc-menu refresh' "$launcher" "launcher does not refresh Corebrum Cloud"
assert_grep 'corebrum-arc-menu.sh' "$desktop_lib" "desktop install does not ship the Corebrum Cloud menu"
assert_grep 'https://cloud.corebrum.com' "$menu" "menu does not open the Corebrum Cloud URL"

if grep -qE 'snap install chromium|--app=|chromium-browser|xdg-open' "$menu"; then
  echo "FAIL: Corebrum Cloud installs Chromium or opens another browser" >&2
  fail=1
fi

runtime="$(mktemp -d)"
export XDG_RUNTIME_DIR="$runtime"

bash "$menu" refresh
desktop="${runtime}/corebrum/applications/corebrum-arc.desktop"
if ! grep -q '^Name=Corebrum Cloud$' "$desktop"; then
  echo "FAIL: Corebrum Cloud row is missing" >&2
  fail=1
fi
if ! grep -q '^Icon=/usr/share/corebrum/icon.png$' "$desktop"; then
  echo "FAIL: the Corebrum Cloud row does not use the Corebrum Synapse mark" >&2
  fail=1
fi
if grep -q 'install' "$desktop"; then
  echo "FAIL: Corebrum Cloud row shows an install mark" >&2
  fail=1
fi

output="$(COREBRUM_ARC_STUB=1 bash "$menu" open)"
if [[ "$output" != "firefox https://cloud.corebrum.com" ]]; then
  echo "FAIL: Corebrum Cloud did not open Firefox (got ${output})" >&2
  fail=1
fi

rm -rf "$runtime"
if [[ "$fail" -ne 0 ]]; then
  exit 1
fi
echo "synapse cloud menu unit tests passed"
