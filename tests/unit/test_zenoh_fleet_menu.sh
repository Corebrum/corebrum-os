#!/usr/bin/env bash
# Zenoh fleet is its own Super+Space entry and is not part of the desktop package list.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
menu="${ROOT}/scripts/desktop/corebrum-zenoh-fleet-menu.sh"
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

assert_grep 'corebrum-zenoh-fleet-menu refresh' "$launcher" "launcher does not refresh Zenoh fleet"
assert_grep 'corebrum-zenoh-fleet-menu.sh' "$desktop_lib" "desktop install does not ship the Zenoh fleet menu"
assert_grep '@agenticros/zenoh-fleet@0\.1\.4' "$menu" "installer does not pin zenoh-fleet 0.1.4"
if grep -q 'zenoh-fleet' "${ROOT}/manifests/packages/desktop.txt"; then
  echo "FAIL: desktop profile preinstalls Zenoh fleet" >&2
  fail=1
fi
if grep -q 'zenohd' "$menu"; then
  echo "FAIL: menu starts or installs zenohd" >&2
  fail=1
fi

runtime="$(mktemp -d)"
export XDG_RUNTIME_DIR="$runtime"
export COREBRUM_ZENOH_FLEET_STUB=1

name="$(COREBRUM_ZENOH_FLEET_READY=0 bash "$menu" entry-name)"
if [[ "$name" != "Zenoh fleet   install" ]]; then
  echo "FAIL: missing Zenoh fleet is not marked install (got ${name})" >&2
  fail=1
fi
name="$(COREBRUM_ZENOH_FLEET_READY=1 bash "$menu" entry-name)"
if [[ "$name" != "Zenoh fleet" ]]; then
  echo "FAIL: installed Zenoh fleet still shows install (got ${name})" >&2
  fail=1
fi

COREBRUM_ZENOH_FLEET_READY=0 bash "$menu" refresh
desktop="${runtime}/corebrum/applications/corebrum-zenoh-fleet.desktop"
if ! grep -q '^Name=Zenoh fleet   install$' "$desktop"; then
  echo "FAIL: desktop entry name is not the install row" >&2
  fail=1
fi
if ! grep -q '^Exec=/usr/local/bin/corebrum-zenoh-fleet-menu open$' "$desktop"; then
  echo "FAIL: desktop entry does not open the Zenoh fleet menu" >&2
  fail=1
fi
if ! grep -q '^Icon=/usr/share/corebrum/zenoh.png$' "$desktop"; then
  echo "FAIL: the Zenoh fleet menu row does not use the Zenoh mark" >&2
  fail=1
fi
if grep -q '^NoDisplay=true$' "$desktop"; then
  echo "FAIL: Zenoh fleet is hidden from the idle menu" >&2
  fail=1
fi

output="$(COREBRUM_ZENOH_FLEET_READY=0 bash "$menu" open)"
if [[ "$output" != *'npm install -g --allow-scripts=@agenticros/zenoh-fleet @agenticros/zenoh-fleet@0.1.4'* ]]; then
  echo "FAIL: selecting Zenoh fleet did not install the npm package (got ${output})" >&2
  fail=1
fi
output="$(COREBRUM_ZENOH_FLEET_READY=1 bash "$menu" open)"
if [[ "$output" != 'zenoh-fleet' ]]; then
  echo "FAIL: installed Zenoh fleet did not launch the wizard (got ${output})" >&2
  fail=1
fi

rm -rf "$runtime"
if [[ "$fail" -ne 0 ]]; then
  exit 1
fi
echo "ok: zenoh fleet menu"
