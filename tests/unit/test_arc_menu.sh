#!/usr/bin/env bash
# AgenticROS Cloud is a Super+Space row that opens the site in the default browser.
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

if grep -qE 'snap install chromium|--app=|chromium-browser' "$menu"; then
  echo "FAIL: AgenticROS Cloud installs Chromium or hides the browser tools" >&2
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

bash_bin="$(command -v bash)"
with_xdg="$(mktemp -d)"
ln -s "$bash_bin" "${with_xdg}/bash"
printf '#!/bin/sh\nexit 0\n' >"${with_xdg}/xdg-open"
chmod 755 "${with_xdg}/xdg-open"
output="$(PATH="${with_xdg}" COREBRUM_ARC_STUB=1 bash "$menu" open)"
if [[ "$output" != "xdg-open https://cloud.agenticros.com" ]]; then
  echo "FAIL: AgenticROS Cloud did not use xdg-open (got ${output})" >&2
  fail=1
fi

without_xdg="$(mktemp -d)"
ln -s "$bash_bin" "${without_xdg}/bash"
output="$(PATH="${without_xdg}" COREBRUM_ARC_STUB=1 bash "$menu" open)"
if [[ "$output" != "firefox https://cloud.agenticros.com" ]]; then
  echo "FAIL: AgenticROS Cloud did not fall back to firefox (got ${output})" >&2
  fail=1
fi

rm -rf "$runtime" "$with_xdg" "$without_xdg"
if [[ "$fail" -ne 0 ]]; then
  exit 1
fi
echo "agenticros cloud menu unit tests passed"
