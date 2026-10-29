#!/usr/bin/env bash
# The desktop profile installs the Firefox snap when the launcher is missing.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export COREBRUM_ROOT="$ROOT"
# shellcheck source=../../scripts/lib/log.sh
source "${ROOT}/scripts/lib/log.sh"
# shellcheck source=../../scripts/lib/desktop.sh
source "${ROOT}/scripts/lib/desktop.sh"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

snap() {
  printf '%s\n' "$*" >>"${tmp}/snap.log"
}

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

phase="${ROOT}/scripts/phases/02-desktop.sh"
apt_line="$(grep -n 'corebrum_apt_install --no-install-recommends' "$phase" | head -n 1 | cut -d: -f1)"
snap_line="$(grep -n 'corebrum_install_firefox_snap$' "$phase" | head -n 1 | cut -d: -f1)"
if [[ -z "$apt_line" || -z "$snap_line" || "$snap_line" -le "$apt_line" ]]; then
  fail "the desktop phase does not install the Firefox snap after apt"
fi
if ! grep -q 'snap install firefox' "${ROOT}/scripts/lib/desktop.sh"; then
  fail "the desktop helper does not run snap install firefox"
fi
if ! grep -q '/snap/bin/firefox' "${ROOT}/scripts/validate/desktop.sh"; then
  fail "desktop validate does not check the Firefox snap launcher"
fi

: >"${tmp}/snap.log"
DRY_RUN=0
COREBRUM_FIREFOX_BIN="${tmp}/missing"
corebrum_install_firefox_snap
if [[ "$(cat "${tmp}/snap.log")" != "install firefox" ]]; then
  fail "a missing launcher should run snap install firefox"
fi

printf '#!/bin/sh\nexit 0\n' >"${tmp}/firefox"
chmod 755 "${tmp}/firefox"
: >"${tmp}/snap.log"
COREBRUM_FIREFOX_BIN="${tmp}/firefox"
corebrum_install_firefox_snap
if [[ -s "${tmp}/snap.log" ]]; then
  fail "an installed launcher should leave the snap alone"
fi

: >"${tmp}/snap.log"
DRY_RUN=1
COREBRUM_FIREFOX_BIN="${tmp}/still-missing"
if ! corebrum_install_firefox_snap 2>"${tmp}/dry.log"; then
  fail "dry-run should succeed"
fi
if [[ -s "${tmp}/snap.log" ]]; then
  fail "dry-run should not run snap"
fi
if ! grep -q 'dry-run: snap install firefox' "${tmp}/dry.log"; then
  fail "dry-run should log snap install firefox"
fi

echo "ok: firefox snap"
