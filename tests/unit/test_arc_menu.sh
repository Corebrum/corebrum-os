#!/usr/bin/env bash
# AgenticROS Cloud is a Super+Space row that opens the site in Firefox.
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

assert_grep 'corebrum-arc-menu refresh' "$launcher" "launcher does not refresh AgenticROS Cloud"
assert_grep 'corebrum-arc-menu.sh' "$desktop_lib" "desktop install does not ship the AgenticROS Cloud menu"
assert_grep 'https://cloud.agenticros.com' "$menu" "menu does not open the AgenticROS Cloud URL"

if grep -qE 'snap install chromium|--app=|chromium-browser|xdg-open' "$menu"; then
  echo "FAIL: AgenticROS Cloud installs Chromium or opens another browser" >&2
  fail=1
fi

runtime="$(mktemp -d)"
export XDG_RUNTIME_DIR="$runtime"

bash "$menu" refresh
desktop="${runtime}/corebrum/applications/corebrum-arc.desktop"
if ! grep -q '^Name=AgenticROS Cloud (ARC)$' "$desktop"; then
  echo "FAIL: AgenticROS Cloud row is missing" >&2
  fail=1
fi
if ! grep -q '^Icon=/usr/share/corebrum/agenticros.png$' "$desktop"; then
  echo "FAIL: the AgenticROS Cloud row does not use the AgenticROS mark" >&2
  fail=1
fi
if grep -q 'install' "$desktop"; then
  echo "FAIL: AgenticROS Cloud row shows an install mark" >&2
  fail=1
fi

output="$(COREBRUM_ARC_STUB=1 bash "$menu" open)"
if [[ "$output" != "firefox https://cloud.agenticros.com" ]]; then
  echo "FAIL: AgenticROS Cloud did not open Firefox (got ${output})" >&2
  fail=1
fi

rm -rf "$runtime"
if [[ "$fail" -ne 0 ]]; then
  exit 1
fi
echo "agenticros cloud menu unit tests passed"
