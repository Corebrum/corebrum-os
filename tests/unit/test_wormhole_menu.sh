#!/usr/bin/env bash
# Wormhole is a Super+Space file transfer and is not part of the desktop package list.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
menu="${ROOT}/scripts/desktop/corebrum-wormhole-menu.sh"
fail=0

assert_grep() {
  local pattern="$1" file="$2" message="$3"
  if ! grep -qE -e "$pattern" "$file"; then
    echo "FAIL: ${message}" >&2
    fail=1
  fi
}

assert_grep 'corebrum-wormhole-menu refresh' "${ROOT}/scripts/desktop/corebrum-launcher.sh" "launcher does not refresh Wormhole"
assert_grep 'corebrum-wormhole-menu.sh' "${ROOT}/scripts/lib/desktop.sh" "desktop install does not install the Wormhole menu"
assert_grep '/usr/local/bin/corebrum-wormhole-menu' "${ROOT}/scripts/lib/desktop.sh" "desktop uninstall does not remove the Wormhole menu"
assert_grep '/usr/local/bin/corebrum-wormhole-menu' "${ROOT}/scripts/validate/desktop.sh" "desktop validator does not require the Wormhole menu"
assert_grep 'apt-get install -y magic-wormhole' "$menu" "installer does not install Ubuntu magic-wormhole"
assert_grep 'magic-wormhole is not in this Ubuntu archive' "$menu" "installer does not explain a missing archive package"
assert_grep 'wormhole send --' "$menu" "Send does not run wormhole send"
assert_grep 'wormhole receive --' "$menu" "Receive does not run wormhole receive"
assert_grep 'HOME/Downloads' "$menu" "Receive does not save into Downloads"
if grep -qE '^magic-wormhole$' "${ROOT}/manifests/packages/desktop.txt"; then
  echo "FAIL: desktop profile preinstalls magic-wormhole" >&2
  fail=1
fi
if ! grep -q '0.12.0-1.1' "${ROOT}/docs/installation/desktop.md"; then
  echo "FAIL: desktop install docs omit the Ubuntu 24.04 package" >&2
  fail=1
fi
if ! grep -q '0.18.0-1build1' "${ROOT}/docs/installation/desktop.md"; then
  echo "FAIL: desktop install docs omit the Ubuntu 26.04 package" >&2
  fail=1
fi
if ! grep -q 'magic-wormhole' "${ROOT}/config/getting-started/desktop.html"; then
  echo "FAIL: Getting Started desktop page does not mention Wormhole" >&2
  fail=1
fi

runtime="$(mktemp -d)"
export XDG_RUNTIME_DIR="$runtime"
export COREBRUM_WORMHOLE_STUB=1

name="$(COREBRUM_WORMHOLE_READY=0 bash "$menu" entry-name)"
if [[ "$name" != "Wormhole   install" ]]; then
  echo "FAIL: missing wormhole is not marked install (got ${name})" >&2
  fail=1
fi
name="$(COREBRUM_WORMHOLE_READY=1 bash "$menu" entry-name)"
if [[ "$name" != "Wormhole" ]]; then
  echo "FAIL: installed wormhole still shows install (got ${name})" >&2
  fail=1
fi

output="$(COREBRUM_WORMHOLE_READY=0 bash "$menu" open)"
if [[ "$output" != *'apt-get install -y magic-wormhole'* ]]; then
  echo "FAIL: selecting Wormhole did not install magic-wormhole" >&2
  fail=1
fi
if [[ "$output" != *'magic-wormhole is not in this Ubuntu archive.'* ]]; then
  echo "FAIL: the installer does not explain a missing archive package" >&2
  fail=1
fi

output="$(COREBRUM_WORMHOLE_READY=1 bash "$menu" open)"
if [[ "$output" != $'Send\nReceive' ]]; then
  echo "FAIL: wormhole list was ${output}" >&2
  fail=1
fi

output="$(COREBRUM_WORMHOLE_READY=1 COREBRUM_WORMHOLE_CHOICE=Send bash "$menu" open)"
if [[ "$output" != *'wormhole send -- "$path"'* ]]; then
  echo "FAIL: Send did not run wormhole send" >&2
  fail=1
fi
if [[ "$output" != *'Press Enter to close.'* ]]; then
  echo "FAIL: Send closes before the code can be read" >&2
  fail=1
fi

output="$(COREBRUM_WORMHOLE_READY=1 COREBRUM_WORMHOLE_CHOICE=Receive bash "$menu" open)"
if [[ "$output" != *'wormhole receive -- "$code"'* ]]; then
  echo "FAIL: Receive did not run wormhole receive" >&2
  fail=1
fi
if [[ "$output" != *'$HOME/Downloads'* ]]; then
  echo "FAIL: Receive does not use Downloads" >&2
  fail=1
fi
if [[ "$output" == *'--accept-file'* ]]; then
  echo "FAIL: Receive skips Wormhole confirmation" >&2
  fail=1
fi

COREBRUM_WORMHOLE_READY=0 bash "$menu" refresh
desktop="${runtime}/corebrum/applications/corebrum-wormhole.desktop"
if ! grep -q '^Name=Wormhole   install$' "$desktop"; then
  echo "FAIL: the Wormhole row is not marked install" >&2
  fail=1
fi
if ! grep -q '^Keywords=wormhole;send;receive;files$' "$desktop"; then
  echo "FAIL: the Wormhole row cannot be found by send, receive, or files" >&2
  fail=1
fi
if ! grep -q '^Exec=/usr/local/bin/corebrum-wormhole-menu open$' "$desktop"; then
  echo "FAIL: the Wormhole row does not open the menu" >&2
  fail=1
fi

rm -rf "$runtime"
if [[ "$fail" -ne 0 ]]; then
  exit 1
fi
echo "wormhole menu unit tests passed"
