#!/usr/bin/env bash
# Chromium is its own Super+Space entry and is not part of the desktop package list.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
menu="${ROOT}/scripts/desktop/corebrum-chromium-menu.sh"
launcher="${ROOT}/scripts/desktop/corebrum-launcher.sh"
fail=0

assert_grep() {
  local pattern="$1" file="$2" message="$3"
  if ! grep -qE "$pattern" "$file"; then
    echo "FAIL: ${message}" >&2
    fail=1
  fi
}

assert_grep 'corebrum-chromium-menu refresh' "$launcher" "launcher does not refresh Chromium"
assert_grep 'apt-get install -y chromium-browser snapd' "$menu" "installer does not install the Ubuntu Chromium packages"
assert_grep 'snap install chromium' "$menu" "installer does not install the Chromium snap"
assert_grep '/snap/bin/chromium' "$menu" "launch does not use the snap binary"
if grep -q 'google-chrome' "$menu"; then
  echo "FAIL: menu uses Google Chrome" >&2
  fail=1
fi
if grep -q '^chromium' "${ROOT}/manifests/packages/desktop.txt"; then
  echo "FAIL: desktop profile preinstalls Chromium" >&2
  fail=1
fi

runtime="$(mktemp -d)"
export XDG_RUNTIME_DIR="$runtime"
export COREBRUM_CHROMIUM_STUB=1

name="$(COREBRUM_CHROMIUM_READY=0 bash "$menu" entry-name)"
if [[ "$name" != "Chromium   install" ]]; then
  echo "FAIL: missing Chromium is not marked install (got ${name})" >&2
  fail=1
fi
name="$(COREBRUM_CHROMIUM_READY=1 bash "$menu" entry-name)"
if [[ "$name" != "Chromium" ]]; then
  echo "FAIL: installed Chromium still shows install (got ${name})" >&2
  fail=1
fi

COREBRUM_CHROMIUM_READY=0 bash "$menu" refresh
desktop="${runtime}/corebrum/applications/corebrum-chromium.desktop"
if ! grep -q '^Name=Chromium   install$' "$desktop"; then
  echo "FAIL: desktop entry name is not the install row" >&2
  fail=1
fi
if ! grep -q '^Exec=/usr/local/bin/corebrum-chromium-menu open$' "$desktop"; then
  echo "FAIL: desktop entry does not open the Chromium menu" >&2
  fail=1
fi
if ! grep -Eq '^Icon=(chromium|/snap/chromium/current/chromium.png)$' "$desktop"; then
  echo "FAIL: Chromium row has no Chromium icon" >&2
  fail=1
fi
for id in chromium_chromium.desktop chromium_daemon.desktop; do
  hidden="${runtime}/corebrum/applications/${id}"
  if ! grep -q '^NoDisplay=true$' "$hidden"; then
    echo "FAIL: ${id} is still listed beside Corebrum's Chromium entry" >&2
    fail=1
  fi
done
if ! grep -q '^filter-desktop=yes$' "${ROOT}/config/fuzzel/fuzzel.ini"; then
  echo "FAIL: Super+Space does not filter OnlyShowIn desktop entries" >&2
  fail=1
fi

output="$(COREBRUM_CHROMIUM_READY=0 bash "$menu" open)"
if [[ "$output" != *'snap install chromium'* ]]; then
  echo "FAIL: selecting Chromium did not install the snap" >&2
  fail=1
fi
output="$(COREBRUM_CHROMIUM_READY=1 bash "$menu" open)"
if [[ "$output" != "/snap/bin/chromium" ]]; then
  echo "FAIL: installed Chromium did not launch (got ${output})" >&2
  fail=1
fi

rm -rf "$runtime"
if [[ "$fail" -ne 0 ]]; then
  exit 1
fi
echo "chromium menu unit tests passed"
