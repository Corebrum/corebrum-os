# 0127. Super+Space menu above fullscreen

Date: 2026-11-06
Status: Accepted

## Context

Super+Space opens the grouped application menu (`corebrum-launcher.py`) or Fuzzel when GTK cannot start. The GTK path used gtk-layer-shell with `GTK_LAYER_SHELL_LAYER_TOP`, which sits below a fullscreen client on Sway. A fullscreen window therefore hid the menu until the operator left fullscreen.

## Decision

- When gtk-layer-shell is used, the launcher window uses `GTK_LAYER_SHELL_LAYER_OVERLAY` (3) so it stacks above fullscreen surfaces.
- Core Fuzzel config sets `layer=overlay` in `[main]` so the fallback matches.

## Consequences

Fullscreen video or demos still show Super+Space on top. Overlay order relative to other overlay clients (for example Mako notifications) follows the compositor. Fuzzel’s own documentation notes an undefined order when several clients share overlay; lock screens also use overlay, so behavior near gtklock is unchanged from depending on compositor stacking.
