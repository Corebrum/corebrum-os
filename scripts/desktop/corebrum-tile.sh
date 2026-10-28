#!/usr/bin/env bash
# Focus or swap the tiled window in a screen direction.
# Sway's focus and move commands follow the container tree. A window below
# another can sit in a different branch, so the arrow does not match the
# screen. This helper uses each tile's rectangle instead.
set -euo pipefail

corebrum_tile_target() {
  local direction="$1"
  python3 -c '
import json
import sys

direction = sys.argv[1]

def find_focused(node):
    found = None

    def walk(current):
        nonlocal found
        if current.get("focused"):
            found = current
        for key in ("nodes", "floating_nodes"):
            for child in current.get(key) or []:
                walk(child)

    walk(node)
    return found

def tiled_leaves(node, found):
    if node.get("type") == "workspace" and node.get("name") == "__i3_scratch":
        return
    nodes = node.get("nodes") or []
    floats = node.get("floating_nodes") or []
    if not nodes and not floats:
        if node.get("type") != "con":
            return
        if node.get("visible") is False:
            return
        if (node.get("floating") or "") in ("user_on", "auto_on"):
            return
        if (node.get("scratchpad_state") or "none") != "none":
            return
        rect = node.get("rect") or {}
        if (rect.get("width") or 0) <= 0 or (rect.get("height") or 0) <= 0:
            return
        found.append(node)
        return
    for child in nodes:
        tiled_leaves(child, found)
    for child in floats:
        tiled_leaves(child, found)

def ranges_overlap(a0, a1, b0, b1):
    return a0 < b1 and b0 < a1

def gap(a0, a1, b0, b1):
    if b0 >= a1:
        return b0 - a1
    if b1 <= a0:
        return b1 - a0
    return 0

def placements(origin, other):
    here, there = origin["rect"], other["rect"]
    gx = gap(here["x"], here["x"] + here["width"], there["x"], there["x"] + there["width"])
    gy = gap(here["y"], here["y"] + here["height"], there["y"], there["y"] + there["height"])
    cx = (there["x"] + there["width"] / 2) - (here["x"] + here["width"] / 2)
    cy = (there["y"] + there["height"] / 2) - (here["y"] + here["height"] / 2)
    horizontal = ranges_overlap(here["y"], here["y"] + here["height"], there["y"], there["y"] + there["height"])
    vertical = ranges_overlap(here["x"], here["x"] + here["width"], there["x"], there["x"] + there["width"])

    def toward(name, distance, overlap, perp):
        return name, (0 if overlap else 1, distance, perp, there["y"], there["x"], other["id"])

    if gx == 0 and gy == 0:
        if cx == 0 and cy == 0:
            return []
        if abs(cx) >= abs(cy) and cx != 0:
            name = "right" if cx > 0 else "left"
            return [toward(name, abs(cx), horizontal, abs(cy))]
        if cy != 0:
            name = "down" if cy > 0 else "up"
            return [toward(name, abs(cy), vertical, abs(cx))]
        return []
    if gy == 0 and gx != 0:
        name = "right" if gx > 0 else "left"
        return [toward(name, abs(gx), horizontal, abs(cy))]
    if gx == 0 and gy != 0:
        name = "down" if gy > 0 else "up"
        return [toward(name, abs(gy), vertical, abs(cx))]
    found = []
    if abs(gx) >= abs(gy):
        name = "right" if gx > 0 else "left"
        found.append(toward(name, abs(gx), horizontal, abs(cy)))
    if abs(gy) >= abs(gx):
        name = "down" if gy > 0 else "up"
        found.append(toward(name, abs(gy), vertical, abs(cx)))
    return found

tree = json.load(sys.stdin)
focused = find_focused(tree)
if focused is None:
    sys.exit(0)
windows = []
tiled_leaves(tree, windows)
best = None
best_id = None
for window in windows:
    if window.get("id") == focused.get("id"):
        continue
    for name, score in placements(focused, window):
        if name != direction:
            continue
        if best is None or score < best:
            best = score
            best_id = window["id"]
if best_id is not None:
    print(best_id)
' "$direction"
}

if [[ "${BASH_SOURCE[0]}" != "$0" ]]; then
  return 0
fi

action="${1:-}"
direction="${2:-}"
case "$action" in
  focus|swap) ;;
  *)
    echo "usage: corebrum-tile focus|swap left|right|up|down" >&2
    exit 2
    ;;
esac
case "$direction" in
  left|right|up|down) ;;
  *)
    echo "usage: corebrum-tile focus|swap left|right|up|down" >&2
    exit 2
    ;;
esac

target="$(swaymsg -t get_tree | corebrum_tile_target "$direction" || true)"
if [[ ! "$target" =~ ^[0-9]+$ ]]; then
  exit 0
fi
if [[ "$action" == focus ]]; then
  swaymsg "[con_id=${target}] focus" >/dev/null
else
  swaymsg "swap container with con_id ${target}" >/dev/null
fi
