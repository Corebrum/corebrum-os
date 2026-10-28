#!/usr/bin/env bash
# Super+Arrows follow the tiles on screen, not Sway's container tree.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
script="${ROOT}/scripts/desktop/corebrum-tile.sh"
# shellcheck source=../../scripts/desktop/corebrum-tile.sh
source "$script"

fail=0

expect() {
  local got="$1" want="$2" message="$3"
  if [[ "$got" != "$want" ]]; then
    echo "FAIL: ${message} (got ${got:-<none>}, want ${want:-<none>})" >&2
    fail=1
  fi
}

# H[V[A C] V[B D]] looks like a grid. Tree order would move right from C to B.
grid="$(cat <<'EOF'
{"type":"root","nodes":[{"type":"output","nodes":[
  {"type":"workspace","visible":true,"nodes":[{"type":"con","layout":"splith","nodes":[
    {"type":"con","layout":"splitv","nodes":[
      {"type":"con","id":1,"focused":false,"visible":true,"floating":"auto_off","scratchpad_state":"none","rect":{"x":0,"y":0,"width":960,"height":540},"nodes":[]},
      {"type":"con","id":3,"focused":true,"visible":true,"floating":"auto_off","scratchpad_state":"none","rect":{"x":0,"y":540,"width":960,"height":540},"nodes":[]}
    ]},
    {"type":"con","layout":"splitv","nodes":[
      {"type":"con","id":2,"focused":false,"visible":true,"floating":"auto_off","scratchpad_state":"none","rect":{"x":960,"y":0,"width":960,"height":540},"nodes":[]},
      {"type":"con","id":4,"focused":false,"visible":true,"floating":"auto_off","scratchpad_state":"none","rect":{"x":960,"y":540,"width":960,"height":540},"nodes":[]}
    ]}
  ]}]},
  {"type":"workspace","name":"2","nodes":[{"type":"con","id":9,"focused":false,"visible":false,"floating":"auto_off","rect":{"x":100,"y":540,"width":100,"height":100},"nodes":[]}]}
]}]}
EOF
)"

expect "$(printf '%s' "$grid" | corebrum_tile_target right)" "4" "right from the lower left tile skips the upper right tile"
expect "$(printf '%s' "$grid" | corebrum_tile_target up)" "1" "up from the lower left tile skips the upper right tile"
expect "$(printf '%s' "$grid" | corebrum_tile_target left)" "" "left from the lower left tile leaves the screen"
expect "$(printf '%s' "$grid" | corebrum_tile_target down)" "" "down from the lower left tile leaves the screen"

master="$(cat <<'EOF'
{"type":"root","focused":false,"nodes":[{"type":"output","nodes":[{"type":"workspace","visible":true,"nodes":[
  {"type":"con","id":10,"focused":true,"visible":true,"floating":"auto_off","scratchpad_state":"none","rect":{"x":0,"y":0,"width":960,"height":1080},"nodes":[]},
  {"type":"con","layout":"splitv","nodes":[
    {"type":"con","id":11,"focused":false,"visible":true,"floating":"auto_off","scratchpad_state":"none","rect":{"x":960,"y":0,"width":960,"height":540},"nodes":[]},
    {"type":"con","id":12,"focused":false,"visible":true,"floating":"auto_off","scratchpad_state":"none","rect":{"x":960,"y":540,"width":960,"height":540},"nodes":[]},
    {"type":"con","id":13,"focused":false,"floating":"user_on","scratchpad_state":"none","rect":{"x":1400,"y":100,"width":200,"height":200},"nodes":[]}
  ]}
]}]}]}
EOF
)"

expect "$(printf '%s' "$master" | corebrum_tile_target right)" "11" "right from a tall tile enters the top of the next column"
expect "$(printf '%s' "$master" | corebrum_tile_target down)" "" "down from a full-height tile stays put"

# Each tall tile sits in its own vertical split. Down must not cross to the other column.
pair="$(cat <<'EOF'
{"type":"root","nodes":[{"type":"output","nodes":[{"type":"workspace","name":"1","layout":"splith","nodes":[
  {"type":"con","layout":"splitv","nodes":[
    {"type":"con","id":48,"focused":false,"visible":true,"floating":"auto_off","scratchpad_state":"none","rect":{"x":12,"y":46,"width":946,"height":1022},"nodes":[]}
  ]},
  {"type":"con","layout":"splitv","nodes":[
    {"type":"con","id":19,"focused":true,"visible":true,"floating":"auto_off","scratchpad_state":"none","rect":{"x":962,"y":46,"width":946,"height":1022},"nodes":[]}
  ]}
]}]}]}
EOF
)"

expect "$(printf '%s' "$pair" | corebrum_tile_target left)" "48" "left from the right column crosses to the tile beside it"
expect "$(printf '%s' "$pair" | corebrum_tile_target down)" "" "down from a side-by-side tile stays in that column"
expect "$(printf '%s' "$pair" | corebrum_tile_target right)" "" "right from the right column leaves the screen"

if ! grep -q 'corebrum-tile focus left' "${ROOT}/config/sway/config"; then
  echo "FAIL: Super+Left still follows the container tree" >&2
  fail=1
fi
if grep -qE 'bindsym \$mod\+(Left|Right|Up|Down) focus' "${ROOT}/config/sway/config"; then
  echo "FAIL: an arrow key still uses Sway focus" >&2
  fail=1
fi
if grep -qE 'bindsym \$mod\+Shift\+(Left|Right|Up|Down) move' "${ROOT}/config/sway/config"; then
  echo "FAIL: Super+Shift+Arrow still uses Sway move" >&2
  fail=1
fi

if [[ "$fail" -ne 0 ]]; then
  exit 1
fi
echo "tile unit tests passed"
