#!/usr/bin/env bash
# Skills is a Super+Space row after Corebrum Synapse is installed. Refresh does not install.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
menu="${ROOT}/scripts/desktop/corebrum-skills-menu.sh"
approve="${ROOT}/scripts/desktop/corebrum-skills-approve.sh"
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

assert_grep 'corebrum-skills-menu refresh' "$launcher" "launcher does not refresh Skills"
assert_grep 'corebrum-skills-menu.sh' "$desktop_lib" "desktop install does not ship the Skills menu"
assert_grep 'corebrum-skills-approve.sh' "$desktop_lib" "desktop install does not ship the approve helper"

if awk '
  /^corebrum_skills_refresh\(\)/ { show = 1 }
  show { print }
  show && /^}/ { exit }
' "$menu" | grep -q 'skills install'; then
  echo "FAIL: Skills refresh installs a skill" >&2
  fail=1
fi

runtime="$(mktemp -d)"
export XDG_RUNTIME_DIR="$runtime"
export COREBRUM_SKILLS_STUB=1

COREBRUM_SKILLS_READY=0 bash "$menu" refresh
desktop="${runtime}/corebrum/applications/corebrum-skills.desktop"
if [[ -f "$desktop" ]]; then
  echo "FAIL: Skills is listed before Corebrum Synapse is installed" >&2
  fail=1
fi

COREBRUM_SKILLS_READY=1 bash "$menu" refresh
if ! grep -q '^Name=Corebrum Skills$' "$desktop"; then
  echo "FAIL: Corebrum Skills row is missing" >&2
  fail=1
fi
if ! grep -q '^Icon=/usr/share/corebrum/icon.png$' "$desktop"; then
  echo "FAIL: the Skills menu row does not use the Corebrum Synapse mark" >&2
  fail=1
fi
if grep -q 'skills install' "$desktop"; then
  echo "FAIL: Skills desktop entry installs a skill" >&2
  fail=1
fi

output="$(COREBRUM_SKILLS_READY=1 bash "$menu" open)"
if [[ "$output" != *List* || "$output" != *Install* ]]; then
  echo "FAIL: Skills did not list its actions (got ${output})" >&2
  fail=1
fi

output="$(COREBRUM_SKILLS_READY=1 COREBRUM_SKILLS_CHOICE=List bash "$menu" open)"
if [[ "$output" != *'synapse skills list'* || "$output" != *'Press Enter to close.'* ]]; then
  echo "FAIL: List did not keep the terminal open (got ${output})" >&2
  fail=1
fi

output="$(COREBRUM_SKILLS_READY=1 COREBRUM_SKILLS_CHOICE=Install COREBRUM_SKILLS_QUERY=synapse/navigate-to bash "$menu" open)"
if [[ "$output" != *'synapse skills install synapse/navigate-to'* || "$output" != *'Press Enter to close.'* ]]; then
  echo "FAIL: Install did not keep the terminal open (got ${output})" >&2
  fail=1
fi

set +e
COREBRUM_SKILLS_APPROVE_ANSWER=no bash "$approve" "Navigate" "@synapse" "Drive to a place." >/dev/null
status=$?
set -e
if [[ "$status" -eq 0 ]]; then
  echo "FAIL: approve helper accepted a no" >&2
  fail=1
fi

set +e
answer="$(COREBRUM_SKILLS_APPROVE_ANSWER=yes bash "$approve" "Navigate" "@synapse" "Drive to a place.")"
status=$?
set -e
if [[ "$status" -ne 0 || "$answer" != "Yes" ]]; then
  echo "FAIL: approve helper did not accept yes (status ${status}, got ${answer})" >&2
  fail=1
fi

rm -rf "$runtime"
if [[ "$fail" -ne 0 ]]; then
  exit 1
fi
