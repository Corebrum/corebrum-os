#!/usr/bin/env bash
# Skills is a Super+Space row after Corebrum Synapse is installed. Refresh does not install.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
menu="${ROOT}/scripts/desktop/corebrum-skills-menu.sh"
approve="${ROOT}/scripts/desktop/corebrum-skills-approve.sh"
launcher="${ROOT}/scripts/desktop/corebrum-launcher.sh"
desktop_lib="${ROOT}/scripts/lib/desktop.sh"
decision="${ROOT}/docs/decisions/0119-skills-restart-deps.md"
search_decision="${ROOT}/docs/decisions/0120-skills-search-install.md"
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
assert_grep 'AI agents must be started again' "$decision" "decision does not describe the restart reminder"
assert_grep 'Open ROS' "$decision" "decision does not describe the ROS follow-up"
assert_grep 'marketplace ref' "$search_decision" "search-install decision is missing"
assert_grep 'Pick a skill to install' "$menu" "Search does not offer a pick-to-install list"
assert_grep 'Number to remove' "$menu" "List does not offer remove-by-number"
assert_grep 'registered skill' "${ROOT}/docs/decisions/0121-skills-list-remove.md" "list-remove decision is missing"

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

list_json='[{"id":"follow-me-ros","packageName":"@corebrum/follow-me-ros"},{"id":"followmeros","packageName":"@corebrum/follow-me-ros"}]'
output="$(
  COREBRUM_SKILLS_READY=1 \
  COREBRUM_SKILLS_CHOICE=List \
  COREBRUM_SKILLS_LIST_JSON="$list_json" \
  bash "$menu" open
)"
if [[ "$output" != *'Registered skills:'* || "$output" != *'follow-me-ros'* ]]; then
  echo "FAIL: List did not show registered skills (got ${output})" >&2
  fail=1
fi
if [[ "$output" != *'Number to remove, or Enter to close.'* || "$output" != *'Press Enter to close.'* ]]; then
  echo "FAIL: List did not offer remove-or-close (got ${output})" >&2
  fail=1
fi

output="$(
  COREBRUM_SKILLS_READY=1 \
  COREBRUM_SKILLS_CHOICE=List \
  COREBRUM_SKILLS_LIST_JSON="$list_json" \
  COREBRUM_SKILLS_QUERY=1 \
  bash "$menu" open
)"
if [[ "$output" != *'synapse skills remove --yes follow-me-ros'* ]]; then
  echo "FAIL: List pick 1 did not remove the first registered id (got ${output})" >&2
  fail=1
fi

output="$(
  COREBRUM_SKILLS_READY=1 \
  COREBRUM_SKILLS_CHOICE=Remove \
  COREBRUM_SKILLS_LIST_JSON="$list_json" \
  COREBRUM_SKILLS_QUERY=2 \
  bash "$menu" open
)"
if [[ "$output" != *'synapse skills remove --yes followmeros'* ]]; then
  echo "FAIL: Remove pick 2 did not use the registered id (got ${output})" >&2
  fail=1
fi

output="$(COREBRUM_SKILLS_READY=1 COREBRUM_SKILLS_CHOICE=Install COREBRUM_SKILLS_QUERY=synapse/navigate-to bash "$menu" open)"
if [[ "$output" != *'synapse skills install synapse/navigate-to'* ]]; then
  echo "FAIL: Install did not run synapse skills install (got ${output})" >&2
  fail=1
fi
if [[ "$output" != *'Restart AI agents so they load the new skill tools.'* ]]; then
  echo "FAIL: Install did not remind the operator to restart agents (got ${output})" >&2
  fail=1
fi
if [[ "$output" != *'This skill needs Nav2'* ]]; then
  echo "FAIL: navigate-to install omitted the Nav2 dependency hint (got ${output})" >&2
  fail=1
fi
if [[ "$output" != *'Open AI Agents'* || "$output" != *'Open ROS'* ]]; then
  echo "FAIL: navigate-to install omitted AI Agents or ROS follow-up (got ${output})" >&2
  fail=1
fi
if [[ "$output" != *'Press Enter to close.'* ]]; then
  echo "FAIL: Install did not keep the terminal open (got ${output})" >&2
  fail=1
fi

output="$(COREBRUM_SKILLS_READY=1 COREBRUM_SKILLS_CHOICE=Install COREBRUM_SKILLS_QUERY=corebrum/halloween bash "$menu" open)"
if [[ "$output" != *'Restart AI agents so they load the new skill tools.'* ]]; then
  echo "FAIL: simple install omitted the restart reminder (got ${output})" >&2
  fail=1
fi
if [[ "$output" == *'Open ROS'* ]]; then
  echo "FAIL: halloween install offered Open ROS without a stack hint (got ${output})" >&2
  fail=1
fi

search_json='[{"marketplaceRef":"codevinoo/surroundings-scan","displayName":"Surroundings Scan"}]'
output="$(
  COREBRUM_SKILLS_READY=1 \
  COREBRUM_SKILLS_CHOICE=Search \
  COREBRUM_SKILLS_QUERY=surroundings \
  COREBRUM_SKILLS_SEARCH_JSON="$search_json" \
  bash "$menu" open
)"
if [[ "$output" != *'synapse skills install codevinoo/surroundings-scan'* ]]; then
  echo "FAIL: Search did not install the marketplace ref (got ${output})" >&2
  fail=1
fi
if [[ "$output" != *'Surroundings Scan'* || "$output" != *'codevinoo/surroundings-scan'* ]]; then
  echo "FAIL: Search did not show the picked skill (got ${output})" >&2
  fail=1
fi
if [[ "$output" != *'Restart AI agents so they load the new skill tools.'* ]]; then
  echo "FAIL: Search install omitted the restart reminder (got ${output})" >&2
  fail=1
fi

output="$(
  COREBRUM_SKILLS_READY=1 \
  COREBRUM_SKILLS_CHOICE=Install \
  COREBRUM_SKILLS_QUERY=surroundings \
  COREBRUM_SKILLS_SEARCH_JSON="$search_json" \
  bash "$menu" open
)"
if [[ "$output" != *'synapse skills install codevinoo/surroundings-scan'* ]]; then
  echo "FAIL: bare Install name did not resolve through search (got ${output})" >&2
  fail=1
fi

rows="$(
  COREBRUM_SKILLS_STUB=1 \
  COREBRUM_SKILLS_SEARCH_JSON="$search_json" \
  bash "$menu" search-rows surroundings
)"
if [[ "$rows" != $'codevinoo/surroundings-scan\tSurroundings Scan' ]]; then
  echo "FAIL: search-rows missed the marketplace ref (got ${rows})" >&2
  fail=1
fi

hints="$(bash "$menu" dep-hints 'dock_to_charger opennav_docking')"
if [[ "$hints" != *'OpenNav'* ]]; then
  echo "FAIL: dep-hints missed OpenNav for docking (got ${hints})" >&2
  fail=1
fi
hints="$(bash "$menu" dep-hints 'pick_object moveit arm')"
if [[ "$hints" != *'MoveIt'* ]]; then
  echo "FAIL: dep-hints missed MoveIt (got ${hints})" >&2
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
echo "ok: skills-menu"
