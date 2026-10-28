# 0086. Copy, cut, and paste on Sway

Date: 2026-10-28
Status: Accepted

## Context

Decision 0028 sends Super+C, Super+X, and Super+V to the focused window. An ordinary window receives Ctrl+C, Ctrl+X, or Ctrl+V. A terminal receives the same key with Shift, because Ctrl+C interrupts the program. The helper did that with `hyprctl dispatch sendshortcut`. Decision 0080 runs Sway. `hyprctl` has no window there, so the helper saw an empty class and sent nothing. Kitty, Firefox, and the text editor all ignored the shortcut.

Ubuntu 26.04 publishes `wtype` 0.4-3build1. It types a chord on its own keyboard, so the Super key that started the shortcut is not part of the chord.

## Decision

- The desktop profile installs `wtype`.
- On Sway, `/usr/local/bin/corebrum-edit-keys` reads the focused window from `swaymsg -t get_tree`. A Wayland window uses `app_id`. An X11 window uses `window_properties.class`.
- The same helper types the chord with `wtype`. Super+K still types Ctrl+Shift+K in a terminal and does nothing in another window.
- Kitty windows started as `corebrum-agent` and `corebrum-setup` are terminals. A session that is still Hyprland keeps `hyprctl dispatch sendshortcut`.

## Consequences

Super+C, Super+X, and Super+V work in the focused window after `wtype` and the helper are installed. A Sway reload is not required. The Keybindings list is unchanged.
