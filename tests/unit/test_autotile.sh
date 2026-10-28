#!/usr/bin/env bash
# New windows split the longer side of the focused tile.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
script="${ROOT}/scripts/desktop/corebrum-autotile.sh"
# shellcheck source=../../scripts/desktop/corebrum-autotile.sh
source "$script"

fail=0

tree() {
  local width="$1" height="$2" parent="$3" floating="${4:-auto_off}" app="${5:-kitty}"
  printf '%s\n' "{\"nodes\":[{\"type\":\"workspace\",\"layout\":\"${parent}\",\"nodes\":[{\"type\":\"con\",\"focused\":true,\"app_id\":\"${app}\",\"floating\":\"${floating}\",\"layout\":\"none\",\"rect\":{\"width\":${width},\"height\":${height}}}]}]}"
}

expect() {
  local got="$1" want="$2" message="$3"
  if [[ "$got" != "$want" ]]; then
    echo "FAIL: ${message} (got ${got:-<none>})" >&2
    fail=1
  fi
}

expect "$(tree 1920 1080 splith | corebrum_autotile_command)" "" "a wide tile already beside its parent still changes split"
expect "$(tree 1920 1080 splitv | corebrum_autotile_command)" "splith" "a wide tile does not open the next window beside it"
expect "$(tree 946 1022 splith | corebrum_autotile_command)" "splitv" "a tall tile does not open the next window below it"
expect "$(tree 946 1022 splitv | corebrum_autotile_command)" "" "a tall tile already below its parent still changes split"
expect "$(tree 800 400 splitv | corebrum_autotile_command)" "splith" "a short tile stacked vertically does not open beside it"
expect "$(tree 946 1022 splith user_on | corebrum_autotile_command)" "" "a floating window changes the split"
expect "$(tree 946 1022 splith auto_off corebrum-agent | corebrum_autotile_command)" "" "the agent scratchpad changes the split"

if grep -q 'split toggle' "$script"; then
  echo "FAIL: autotile still toggles split with no regard to tile shape" >&2
  fail=1
fi
if ! grep -q 'stdbuf -oL swaymsg -t subscribe' "$script"; then
  echo "FAIL: window events stay buffered, so the split never runs" >&2
  fail=1
fi
if ! grep -q '/usr/local/bin/corebrum-autotile' "${ROOT}/config/sway/config"; then
  echo "FAIL: the session does not start autotile" >&2
  fail=1
fi

if [[ "$fail" -ne 0 ]]; then
  exit 1
fi
echo "autotile unit tests passed"
