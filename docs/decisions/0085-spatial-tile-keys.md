# 0085. Arrow keys follow the tiles on screen

Date: 2026-10-28
Status: Accepted

## Context

Super+Arrows ran Sway `focus left|right|up|down`. Super+Shift+Arrows ran Sway `move left|right|up|down`. Both commands walk the container tree. Autotile nests splits, so four tiles that look like a grid are stored as a horizontal split of two vertical splits. From the lower left tile, Super+Right focused the upper right tile, because that branch was the last one focused. Super+Shift+Right moved the window inside that branch and could change the split. The Hyprland session before decision 0080 used `movefocus` and `swapwindow`, which follow the screen.

## Decision

- `/usr/local/bin/corebrum-tile` reads the Sway tree and chooses the tiled window in that direction by rectangle. A window that shares the edge in that direction wins over a nearer window on the diagonal. A hidden workspace, a floating window, and the agent scratchpad are skipped. When no tile lies that way, the key does nothing.
- Super+Left, Super+Right, Super+Up, and Super+Down run `corebrum-tile focus` for that direction.
- Super+Shift plus those arrows run `corebrum-tile swap`. Swap uses Sway `swap container with con_id`, so the two tiles exchange places and the other splits stay put.

## Consequences

The arrow keys match the tiles on screen. A desktop install copies the helper and the Sway binds. The running session keeps the previous binds until those lines are loaded.
