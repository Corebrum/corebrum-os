#!/usr/bin/env bash
# Power is a Super+Space menu. Each action asks again before it runs.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
menu="${ROOT}/scripts/desktop/corebrum-power-menu.sh"
fail=0

if ! grep -q '/usr/local/bin/corebrum-power-menu refresh' "${ROOT}/scripts/desktop/corebrum-launcher.sh"; then
  echo "FAIL: Super+Space does not refresh Power" >&2
  fail=1
fi
if ! grep -q 'corebrum-power-menu.sh' "${ROOT}/scripts/lib/desktop.sh"; then
  echo "FAIL: the desktop install does not copy the Power menu" >&2
  fail=1
fi
if ! grep -q '/usr/local/bin/corebrum-power-menu' "${ROOT}/scripts/lib/desktop.sh"; then
  echo "FAIL: desktop uninstall does not remove the Power menu" >&2
  fail=1
fi
if ! grep -q '/usr/local/bin/corebrum-power-menu' "${ROOT}/scripts/validate/desktop.sh"; then
  echo "FAIL: desktop validation does not check the Power menu" >&2
  fail=1
fi
# shellcheck disable=SC2016
if ! grep -q 'bind = $mainMod SHIFT, E, exit' "${ROOT}/config/hypr/hyprland.conf"; then
  echo "FAIL: Super+Shift+E no longer leaves the session" >&2
  fail=1
fi
if grep -qE 'bind .*systemctl (reboot|poweroff)' "${ROOT}/config/hypr/hyprland.conf"; then
  echo "FAIL: reboot or power off is bound to a key" >&2
  fail=1
fi

output="$(COREBRUM_POWER_STUB=1 bash "$menu" open)"
if [[ "$output" != $'Log out\nReboot\nPower off' ]]; then
  echo "FAIL: power list was ${output}" >&2
  fail=1
fi

output="$(COREBRUM_POWER_STUB=1 COREBRUM_POWER_CHOICE='Power off' bash "$menu" open)"
if [[ "$output" != $'Power off\nCancel' ]]; then
  echo "FAIL: power off confirm was ${output}" >&2
  fail=1
fi

output="$(COREBRUM_POWER_STUB=1 COREBRUM_POWER_CHOICE='Reboot' COREBRUM_POWER_CONFIRM='Cancel' bash "$menu" open)"
if [[ -n "$output" ]]; then
  echo "FAIL: cancel ran ${output}" >&2
  fail=1
fi

output="$(COREBRUM_POWER_STUB=1 COREBRUM_POWER_CHOICE='Log out' COREBRUM_POWER_CONFIRM='Reboot' bash "$menu" open)"
if [[ -n "$output" ]]; then
  echo "FAIL: a mismatched confirm ran ${output}" >&2
  fail=1
fi

output="$(COREBRUM_POWER_STUB=1 COREBRUM_POWER_CHOICE='Log out' COREBRUM_POWER_CONFIRM='Log out' bash "$menu" open)"
if [[ "$output" != "hyprctl dispatch exit" ]]; then
  echo "FAIL: log out command was ${output}" >&2
  fail=1
fi
output="$(COREBRUM_POWER_STUB=1 COREBRUM_POWER_CHOICE='Reboot' COREBRUM_POWER_CONFIRM='Reboot' bash "$menu" open)"
if [[ "$output" != "systemctl reboot" ]]; then
  echo "FAIL: reboot command was ${output}" >&2
  fail=1
fi
output="$(COREBRUM_POWER_STUB=1 COREBRUM_POWER_CHOICE='Power off' COREBRUM_POWER_CONFIRM='Power off' bash "$menu" open)"
if [[ "$output" != "systemctl poweroff" ]]; then
  echo "FAIL: power off command was ${output}" >&2
  fail=1
fi

if COREBRUM_POWER_STUB=1 COREBRUM_POWER_CHOICE='Suspend' bash "$menu" open >/dev/null 2>&1; then
  echo "FAIL: an unknown power row was accepted" >&2
  fail=1
fi

runtime="$(mktemp -d)"
XDG_RUNTIME_DIR="$runtime" bash "$menu" refresh
desktop="${runtime}/corebrum/applications/corebrum-power.desktop"
if ! grep -q '^Name=Power$' "$desktop"; then
  echo "FAIL: Power is not the menu name" >&2
  fail=1
fi
if ! grep -q '^Exec=/usr/local/bin/corebrum-power-menu open$' "$desktop"; then
  echo "FAIL: Power does not open the menu" >&2
  fail=1
fi
if ! grep -q '^Keywords=sign out;shutdown;poweroff;$' "$desktop"; then
  echo "FAIL: search cannot find Power from shutdown or sign out" >&2
  fail=1
fi
if ! grep -q '^Comment=Log out, reboot, or power off$' "$desktop"; then
  echo "FAIL: search cannot find Power from log out, reboot, or power off" >&2
  fail=1
fi
rm -rf "$runtime"

if [[ "$fail" -ne 0 ]]; then
  exit 1
fi
echo "power menu unit tests passed"
