#!/usr/bin/env bash
# Password is under Super+Space Setup. It runs passwd in a terminal.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
menu="${ROOT}/scripts/desktop/corebrum-password-menu.sh"
fail=0

assert_grep() {
  local pattern="$1" file="$2" message="$3"
  if ! grep -qE -e "$pattern" "$file"; then
    echo "FAIL: ${message}" >&2
    fail=1
  fi
}

assert_grep 'corebrum-password-menu refresh' "${ROOT}/scripts/desktop/corebrum-launcher.sh" "launcher does not refresh Password"
assert_grep 'corebrum-password-menu.sh' "${ROOT}/scripts/lib/desktop.sh" "desktop install does not install the Password menu"
assert_grep '/usr/local/bin/corebrum-password-menu' "${ROOT}/scripts/lib/desktop.sh" "desktop uninstall does not remove the Password menu"
assert_grep '/usr/local/bin/corebrum-password-menu' "${ROOT}/scripts/validate/desktop.sh" "desktop validator does not require the Password menu"
assert_grep 'corebrum-password' "${ROOT}/config/menu/corebrum-menu.json" "Setup does not list Password"
assert_grep '"corebrum-password"' "${ROOT}/config/menu/corebrum-menu.json" "Password is not a dynamic Setup leaf"
assert_grep '\bpasswd\b' "$menu" "Password menu does not run passwd"
if grep -q 'gnome-control-center' "$menu"; then
  echo "FAIL: Password launches GNOME Control Center" >&2
  fail=1
fi
if grep -qE 'passwdroot|chpasswd|passwordless|cryptsetup' "$menu"; then
  echo "FAIL: Password menu reaches beyond this account passwd" >&2
  fail=1
fi
if ! grep -q 'passwd' "${ROOT}/config/getting-started/desktop.html"; then
  echo "FAIL: Getting Started desktop page does not mention Password" >&2
  fail=1
fi
if [[ ! -f "${ROOT}/docs/decisions/0115-password-setup.md" ]]; then
  echo "FAIL: decision 0115 is missing" >&2
  fail=1
fi

runtime="$(mktemp -d)"
export XDG_RUNTIME_DIR="$runtime"
export COREBRUM_PASSWORD_STUB=1

output="$(bash "$menu" open)"
if [[ "$output" != "passwd" ]]; then
  echo "FAIL: open stub was ${output}" >&2
  fail=1
fi

bash "$menu" refresh
desktop="${runtime}/corebrum/applications/corebrum-password.desktop"
if ! grep -q '^Name=Password$' "$desktop"; then
  echo "FAIL: desktop Name was $(grep '^Name=' "$desktop" || true)" >&2
  fail=1
fi
if ! grep -q '^Keywords=password;passwd;account;login;credentials;$' "$desktop"; then
  echo "FAIL: search keywords missing on Password desktop" >&2
  fail=1
fi
if ! grep -q '^Exec=/usr/local/bin/corebrum-password-menu open$' "$desktop"; then
  echo "FAIL: desktop does not open Password" >&2
  fail=1
fi

rm -rf "$runtime"

if [[ "$fail" -ne 0 ]]; then
  exit 1
fi
echo "PASS: password menu"
