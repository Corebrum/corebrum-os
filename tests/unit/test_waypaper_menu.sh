#!/usr/bin/env bash
# Waypaper is its own Super+Space entry and is not part of the desktop package list.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
menu="${ROOT}/scripts/desktop/corebrum-waypaper-menu.sh"
launcher="${ROOT}/scripts/desktop/corebrum-launcher.sh"
fail=0

assert_grep() {
  local pattern="$1" file="$2" message="$3"
  if ! grep -qE "$pattern" "$file"; then
    echo "FAIL: ${message}" >&2
    fail=1
  fi
}

assert_grep 'corebrum-waypaper-menu refresh' "$launcher" "launcher does not refresh Waypaper"
assert_grep 'apt-get install -y pipx swaybg python3-gi python3-gi-cairo gir1.2-gtk-3.0' "$menu" "installer does not install the Ubuntu Waypaper packages"
assert_grep "COREBRUM_WAYPAPER_VERSION='2.9'" "$menu" "installer does not pin Waypaper 2.9"
assert_grep 'pipx install --system-site-packages' "$menu" "installer does not use pipx"
assert_grep '.local/bin/waypaper' "$menu" "launch does not use the user Waypaper command"
if grep -q '^waypaper' "${ROOT}/manifests/packages/desktop.txt"; then
  echo "FAIL: desktop profile preinstalls Waypaper" >&2
  fail=1
fi
if grep -q 'hyprpaper' "$menu"; then
  echo "FAIL: Waypaper menu installs hyprpaper" >&2
  fail=1
fi

runtime="$(mktemp -d)"
export XDG_RUNTIME_DIR="$runtime"
export COREBRUM_WAYPAPER_STUB=1

name="$(COREBRUM_WAYPAPER_READY=0 bash "$menu" entry-name)"
if [[ "$name" != "Waypaper   install" ]]; then
  echo "FAIL: missing Waypaper is not marked install (got ${name})" >&2
  fail=1
fi
name="$(COREBRUM_WAYPAPER_READY=1 bash "$menu" entry-name)"
if [[ "$name" != "Waypaper" ]]; then
  echo "FAIL: installed Waypaper still shows install (got ${name})" >&2
  fail=1
fi

COREBRUM_WAYPAPER_READY=0 bash "$menu" refresh
desktop="${runtime}/corebrum/applications/corebrum-waypaper.desktop"
if ! grep -q '^Name=Waypaper   install$' "$desktop"; then
  echo "FAIL: desktop entry name is not the install row" >&2
  fail=1
fi
if ! grep -q '^Exec=/usr/local/bin/corebrum-waypaper-menu open$' "$desktop"; then
  echo "FAIL: desktop entry does not open the Waypaper menu" >&2
  fail=1
fi

output="$(COREBRUM_WAYPAPER_READY=0 bash "$menu" open)"
if [[ "$output" != *'pipx install --system-site-packages '"'"'waypaper==2.9'"'"''* ]]; then
  echo "FAIL: selecting Waypaper did not install the pinned package" >&2
  fail=1
fi
if [[ "$output" != *'swaybg'* ]]; then
  echo "FAIL: selecting Waypaper did not install swaybg" >&2
  fail=1
fi
output="$(HOME=/home/corebrum COREBRUM_WAYPAPER_READY=1 bash "$menu" open)"
if [[ "$output" != "/home/corebrum/.local/bin/waypaper" ]]; then
  echo "FAIL: installed Waypaper did not launch (got ${output})" >&2
  fail=1
fi

rm -rf "$runtime"
if [[ "$fail" -ne 0 ]]; then
  exit 1
fi
echo "waypaper menu unit tests passed"
