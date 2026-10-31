# 0104. Super+Q closes the focused window

Date: 2026-10-31
Status: Accepted

## Context

Super+W runs Sway `kill` on the focused window. Super+Q was left unbound, and the desktop config test rejected a Super+Q close binding. Operators who expect Super+Q from other tiling desktops had no matching shortcut.

## Decision

- `bindsym $mod+q kill` sits beside `bindsym $mod+w kill` in the Sway session config.
- Both chords close the focused window. Super+W stays bound.
- The Keybindings list and the Getting Started keybindings page show both chords.

## Consequences

A reload of the Sway config picks up Super+Q without a new login. Neither chord logs out. Super+Shift+E remains the logout chord.
