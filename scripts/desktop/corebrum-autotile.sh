#!/usr/bin/env bash
# Split the longer side of the focused tile so new windows stay closer to square.
# Sway 1.9 has no dwindle layout. A wide tile opens the next window beside it.
# A tall tile opens the next one below it. Floating windows and the agent
# scratchpad are skipped.
# swaymsg blocks its event stream when stdout is a pipe, so the stream is
# line-buffered. Otherwise a few new windows never change the split.
set -euo pipefail

corebrum_autotile_command() {
  python3 -c '
import json
import sys

def find(node, parent):
    if node.get("focused"):
        return node, parent
    for key in ("nodes", "floating_nodes"):
        for child in node.get(key) or []:
            found, found_parent = find(child, node)
            if found is not None:
                return found, found_parent
    return None, None

focused, parent = find(json.load(sys.stdin), None)
if focused is None or focused.get("type") != "con" or parent is None:
    sys.exit(0)
if focused.get("app_id") == "corebrum-agent":
    sys.exit(0)
if (focused.get("floating") or "") in ("user_on", "auto_on"):
    sys.exit(0)
rect = focused.get("rect") or {}
width = rect.get("width") or 0
height = rect.get("height") or 0
if width <= 0 or height <= 0:
    sys.exit(0)
want = "splith" if width > height else "splitv"
if parent.get("layout") == want:
    sys.exit(0)
print(want)
'
}

corebrum_autotile_apply() {
  local cmd
  cmd="$(swaymsg -t get_tree | corebrum_autotile_command || true)"
  if [[ "$cmd" == splith || "$cmd" == splitv ]]; then
    swaymsg "$cmd" >/dev/null || true
  fi
}

corebrum_autotile_interesting() {
  local line="$1"
  [[ "$line" == *'"change":"new"'* || "$line" == *'"change": "new"'* \
    || "$line" == *'"change":"focus"'* || "$line" == *'"change": "focus"'* \
    || "$line" == *'"change":"move"'* || "$line" == *'"change": "move"'* ]]
}

if [[ "${BASH_SOURCE[0]}" != "$0" ]]; then
  return 0
fi

corebrum_autotile_apply
stdbuf -oL swaymsg -t subscribe -m '["window"]' | while IFS= read -r line; do
  corebrum_autotile_interesting "$line" || continue
  corebrum_autotile_apply
done
