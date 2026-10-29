#!/usr/bin/env bash
# Getting Started is a Super+Space row that opens the local guide in Firefox.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
menu="${ROOT}/scripts/desktop/corebrum-docs-menu.sh"
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

assert_grep 'corebrum-docs-menu refresh' "$launcher" "launcher does not refresh Getting Started"
assert_grep 'corebrum-docs-menu.sh' "$desktop_lib" "desktop install does not ship the Getting Started menu"
assert_grep 'http://127.0.0.1:8765/getting-started/' "$menu" "menu does not open the local guide"

if grep -qE 'snap install chromium|xdg-open|chromium-browser' "$menu"; then
  echo "FAIL: Getting Started installs Chromium or opens another browser" >&2
  fail=1
fi

runtime="$(mktemp -d)"
export XDG_RUNTIME_DIR="$runtime"

bash "$menu" refresh
desktop="${runtime}/corebrum/applications/corebrum-docs.desktop"
if ! grep -q '^Name=Getting Started$' "$desktop"; then
  echo "FAIL: Getting Started row is missing" >&2
  fail=1
fi
if ! grep -q '^Icon=/usr/share/corebrum/icon.png$' "$desktop"; then
  echo "FAIL: the Getting Started row does not use the Corebrum icon" >&2
  fail=1
fi
if ! grep -q '^Exec=/usr/local/bin/corebrum-docs-menu open$' "$desktop"; then
  echo "FAIL: Getting Started row does not open the menu command" >&2
  fail=1
fi
if grep -q 'install' "$desktop"; then
  echo "FAIL: Getting Started row shows an install mark" >&2
  fail=1
fi

output="$(COREBRUM_DOCS_STUB=1 bash "$menu" open)"
if [[ "$output" != "firefox http://127.0.0.1:8765/getting-started/" ]]; then
  echo "FAIL: Getting Started did not open Firefox (got ${output})" >&2
  fail=1
fi

rm -rf "$runtime"
if [[ "$fail" -ne 0 ]]; then
  exit 1
fi
echo "getting started menu unit tests passed"
