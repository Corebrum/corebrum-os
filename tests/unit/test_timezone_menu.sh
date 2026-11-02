#!/usr/bin/env bash
# Timezone is under Super+Space Setup. Fuzzel picks a timedatectl zone.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
menu="${ROOT}/scripts/desktop/corebrum-timezone-menu.sh"
fail=0

assert_grep() {
  local pattern="$1" file="$2" message="$3"
  if ! grep -qE -e "$pattern" "$file"; then
    echo "FAIL: ${message}" >&2
    fail=1
  fi
}

assert_grep 'corebrum-timezone-menu refresh' "${ROOT}/scripts/desktop/corebrum-launcher.sh" "launcher does not refresh Timezone"
assert_grep 'corebrum-timezone-menu.sh' "${ROOT}/scripts/lib/desktop.sh" "desktop install does not install the Timezone menu"
assert_grep '/usr/local/bin/corebrum-timezone-menu' "${ROOT}/scripts/lib/desktop.sh" "desktop uninstall does not remove the Timezone menu"
assert_grep '/usr/local/bin/corebrum-timezone-menu' "${ROOT}/scripts/validate/desktop.sh" "desktop validator does not require the Timezone menu"
assert_grep 'corebrum-timezone' "${ROOT}/config/menu/corebrum-menu.json" "Setup does not list Timezone"
assert_grep '"corebrum-timezone"' "${ROOT}/config/menu/corebrum-menu.json" "Timezone is not a dynamic Setup leaf"
assert_grep 'pkexec timedatectl set-timezone' "$menu" "Timezone does not use pkexec timedatectl"
assert_grep 'timedatectl list-timezones' "$menu" "Timezone does not list system zones"
if grep -q 'gnome-control-center' "$menu"; then
  echo "FAIL: Timezone launches GNOME Control Center" >&2
  fail=1
fi
if ! grep -q 'timedatectl set-timezone' "${ROOT}/config/getting-started/desktop.html"; then
  echo "FAIL: Getting Started desktop page does not mention Timezone" >&2
  fail=1
fi
if [[ ! -f "${ROOT}/docs/decisions/0114-timezone-setup.md" ]]; then
  echo "FAIL: decision 0114 is missing" >&2
  fail=1
fi

runtime="$(mktemp -d)"
export XDG_RUNTIME_DIR="$runtime"
export COREBRUM_TIMEZONE_STUB=1
export COREBRUM_TIMEZONE_CURRENT=America/Phoenix
export COREBRUM_TIMEZONE_LINES=$'America/Phoenix\nAmerica/New_York\nUTC\nEurope/London'

name="$(bash "$menu" entry-name)"
if [[ "$name" != "Timezone   America/Phoenix" ]]; then
  echo "FAIL: entry name was ${name}" >&2
  fail=1
fi

lines="$(bash "$menu" lines)"
if [[ "$lines" != $'America/Phoenix\nAmerica/New_York\nUTC\nEurope/London' ]]; then
  echo "FAIL: lines were ${lines}" >&2
  fail=1
fi
# Current zone must appear once, first.
first="$(printf '%s\n' "$lines" | head -n 1)"
if [[ "$first" != "America/Phoenix" ]]; then
  echo "FAIL: current zone is not first (${first})" >&2
  fail=1
fi
count="$(printf '%s\n' "$lines" | grep -cFx 'America/Phoenix' || true)"
if [[ "$count" -ne 1 ]]; then
  echo "FAIL: current zone listed ${count} times" >&2
  fail=1
fi

output="$(bash "$menu" open)"
if [[ "$output" != $'America/Phoenix\nAmerica/New_York\nUTC\nEurope/London' ]]; then
  echo "FAIL: open without a choice did not list zones (${output})" >&2
  fail=1
fi

output="$(COREBRUM_TIMEZONE_CHOICE=UTC bash "$menu" open)"
if [[ "$output" != "timedatectl set-timezone UTC" ]]; then
  echo "FAIL: choosing UTC applied ${output}" >&2
  fail=1
fi

# No choice: stub lists zones and does not apply (Escape).
output="$(env -u COREBRUM_TIMEZONE_CHOICE COREBRUM_TIMEZONE_STUB=1 \
  COREBRUM_TIMEZONE_CURRENT=UTC COREBRUM_TIMEZONE_LINES=$'UTC\nAmerica/Phoenix' \
  bash "$menu" open)"
if [[ "$output" != $'UTC\nAmerica/Phoenix' ]]; then
  echo "FAIL: cancel list was ${output}" >&2
  fail=1
fi
if [[ "$output" == *'timedatectl set-timezone'* ]]; then
  echo "FAIL: cancel still applied a timezone" >&2
  fail=1
fi

bash "$menu" refresh
desktop="${runtime}/corebrum/applications/corebrum-timezone.desktop"
if ! grep -q '^Name=Timezone   America/Phoenix$' "$desktop"; then
  echo "FAIL: desktop Name was $(grep '^Name=' "$desktop" || true)" >&2
  fail=1
fi
if ! grep -q '^Keywords=timezone;tz;time zone;clock;timedatectl;$' "$desktop"; then
  echo "FAIL: search keywords missing on Timezone desktop" >&2
  fail=1
fi
if ! grep -q '^Exec=/usr/local/bin/corebrum-timezone-menu open$' "$desktop"; then
  echo "FAIL: desktop does not open Timezone" >&2
  fail=1
fi

rm -rf "$runtime"

if [[ "$fail" -ne 0 ]]; then
  exit 1
fi
echo "PASS: timezone menu"
