#!/usr/bin/env bash
# Corebrum Cloud is a Super+Space wizard for login, register, connect, and the site.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
menu="${ROOT}/scripts/desktop/corebrum-arc-menu.sh"
status="${ROOT}/scripts/desktop/corebrum-synapse-status.sh"
launcher="${ROOT}/scripts/desktop/corebrum-launcher.sh"
desktop_lib="${ROOT}/scripts/lib/desktop.sh"
decision="${ROOT}/docs/decisions/0118-cloud-connect-wizard.md"
fail=0

assert_grep() {
  local pattern="$1" file="$2" message="$3"
  if ! grep -qE "$pattern" "$file"; then
    echo "FAIL: ${message}" >&2
    fail=1
  fi
}

assert_eq() {
  local got="$1" expected="$2" message="$3"
  if [[ "$got" != "$expected" ]]; then
    printf 'FAIL: %s\n got: %q\n expected: %q\n' "$message" "$got" "$expected" >&2
    fail=1
  fi
}

launcher_py="${ROOT}/scripts/desktop/corebrum-launcher.py"
menu_json="${ROOT}/config/menu/corebrum-menu.json"
assert_grep 'corebrum-arc-menu refresh' "$launcher" "launcher does not refresh Corebrum Cloud"
assert_grep 'corebrum-arc-menu.sh' "$desktop_lib" "desktop install does not ship the Corebrum Cloud menu"
assert_grep 'https://cloud.corebrum.com' "$menu" "menu does not keep the Corebrum Cloud URL"
assert_grep 'corebrum-arc-action-' "$launcher_py" "launcher search does not include Cloud actions"
assert_grep '"corebrum-arc"' "$menu_json" "menu tree does not list Corebrum Cloud"
assert_grep 'corebrum-arc-action-' "$menu_json" "menu tree does not navigate into Cloud actions"
assert_grep 'synapse login' "$menu" "Set up Cloud does not run synapse login"
assert_grep 'synapse register' "$menu" "Set up Cloud does not run synapse register"
assert_grep 'synapse connect' "$menu" "Set up Cloud does not run synapse connect"
assert_grep 'Corebrum Cloud opens a connect wizard' "$decision" "decision file is missing or mistitled"
assert_grep 'synapse login' "$decision" "decision does not describe the login step"

if grep -qE 'snap install chromium|--app=|chromium-browser|xdg-open' "$menu"; then
  echo "FAIL: Corebrum Cloud installs Chromium or opens another browser" >&2
  fail=1
fi

runtime="$(mktemp -d)"
export XDG_RUNTIME_DIR="$runtime"
export COREBRUM_ARC_STUB=1
export COREBRUM_ARC_SYNAPSE=0
export COREBRUM_ARC_TOKEN=0
export COREBRUM_ARC_CONNECTED=0

bash "$menu" refresh
desktop="${runtime}/corebrum/applications/corebrum-arc.desktop"
if ! grep -q '^Name=Corebrum Cloud$' "$desktop"; then
  echo "FAIL: Corebrum Cloud row is missing" >&2
  fail=1
fi
if ! grep -q '^Icon=/usr/share/corebrum/icon.png$' "$desktop"; then
  echo "FAIL: the Corebrum Cloud row does not use the Corebrum Synapse mark" >&2
  fail=1
fi
if grep -q 'install' "$desktop"; then
  echo "FAIL: Corebrum Cloud row shows an install mark" >&2
  fail=1
fi
setup_entry="${runtime}/corebrum/applications/corebrum-arc-action-setup.desktop"
if ! grep -q '^Name=Cloud: Set up$' "$setup_entry"; then
  echo "FAIL: Super+Space search does not list Cloud: Set up" >&2
  fail=1
fi
if ! grep -q '^NoDisplay=true$' "$setup_entry"; then
  echo "FAIL: Cloud: Set up is listed in the idle Super+Space menu" >&2
  fail=1
fi

assert_eq "$(bash "$menu" status)" "Status: Synapse not installed" "missing Synapse status"
labels="$(bash "$menu" open)"
assert_grep 'Status: Synapse not installed' <(printf '%s\n' "$labels") "open without Synapse omits status"
assert_grep 'Install Corebrum Synapse' <(printf '%s\n' "$labels") "open without Synapse omits install"
assert_grep 'Open website' <(printf '%s\n' "$labels") "open without Synapse omits website"
if grep -qE '^Set up( Cloud)?$' <<<"$labels"; then
  echo "FAIL: Set up is offered before Synapse is installed" >&2
  fail=1
fi

output="$(COREBRUM_ARC_CHOICE='Open website' bash "$menu" open)"
assert_eq "$output" "firefox https://cloud.corebrum.com" "Open website did not open Firefox"

output="$(COREBRUM_ARC_CHOICE='Install Corebrum Synapse' bash "$menu" open)"
assert_eq "$output" "corebrum-synapse-menu open" "missing Synapse does not hand off to the Synapse menu"

export COREBRUM_ARC_SYNAPSE=1
assert_eq "$(bash "$menu" status)" "Status: needs sign-in" "unsigned status"
labels="$(bash "$menu" open)"
assert_grep '^Set up$' <(printf '%s\n' "$labels") "signed-out menu omits Set up"
assert_grep '^Register this robot$' <(printf '%s\n' "$labels") "signed-out menu omits Register"

export COREBRUM_ARC_TOKEN=1
assert_eq "$(bash "$menu" status)" "Status: signed in, not connected" "signed-in idle status"

export COREBRUM_ARC_CONNECTED=1
assert_eq "$(bash "$menu" status)" "Status: connected" "connected status"

output="$(COREBRUM_ARC_CHOICE='Connect' bash "$menu" open)"
assert_eq "$output" "synapse connect" "Connect does not use the CLI"
output="$(COREBRUM_ARC_CHOICE='Disconnect' bash "$menu" open)"
assert_eq "$output" "synapse disconnect" "Disconnect does not use the CLI"
output="$(COREBRUM_ARC_CHOICE='Sign in' bash "$menu" open)"
assert_eq "$output" "synapse login" "Sign in does not use the CLI"
output="$(COREBRUM_ARC_CHOICE='Register this robot' bash "$menu" open)"
assert_eq "$output" "synapse register" "Register does not use the CLI"
output="$(COREBRUM_ARC_CHOICE='Set up' bash "$menu" open)"
if ! grep -q 'synapse login' <<<"$output" || ! grep -q 'synapse register' <<<"$output" || ! grep -q 'synapse connect' <<<"$output"; then
  echo "FAIL: Set up does not walk login, register, and connect" >&2
  printf '%s\n' "$output" >&2
  fail=1
fi
output="$(bash "$menu" launch website)"
assert_eq "$output" "firefox https://cloud.corebrum.com" "launch website did not open Firefox"
output="$(bash "$menu" launch setup)"
if ! grep -q 'synapse whoami' <<<"$output"; then
  echo "FAIL: Set up does not show whoami after connect" >&2
  fail=1
fi
if ! grep -q '^Name=Cloud: Register this robot$' \
  "${runtime}/corebrum/applications/corebrum-arc-action-register.desktop"; then
  echo "FAIL: Super+Space search does not list Register this robot" >&2
  fail=1
fi

export COREBRUM_SYNAPSE_STATUS_STUB=1
click_out="$("$status" click)"
assert_eq "$click_out" "corebrum-arc-menu open" "Waybar Cloud does not open the Corebrum Cloud menu"

rm -rf "$runtime"
if [[ "$fail" -ne 0 ]]; then
  exit 1
fi
echo "synapse cloud menu unit tests passed"
