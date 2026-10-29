# 0095. Super+Space lists one Files row

Date: 2026-10-29
Status: Accepted

## Context

Decision 0019 names the Thunar desktop entry `Files`. Super+Shift+F runs `thunar`. An NVIDIA Jetson starts from Ubuntu Desktop, and the Corebrum desktop install turns that session off. Ubuntu Desktop leaves Nautilus installed. Its desktop entry is `org.gnome.Nautilus.desktop`, and the name is also `Files`. Super+Space then lists two Files rows. Ubuntu Server installs that do not start from Ubuntu Desktop do not ship that entry.

## Decision

- Each Super+Space launch writes `org.gnome.Nautilus.desktop` into the menu runtime directory with `NoDisplay=true`. That file is earlier in `XDG_DATA_DIRS` than `/usr/share/applications`, so it claims the Nautilus desktop ID.
- The visible Files row stays the Thunar override. Super+Shift+F still runs `thunar`.
- The menu does not remove the Nautilus package.

## Consequences

The next Super+Space on a Jetson lists one Files row, and choosing it opens Thunar. A machine without Nautilus writes the same hidden file and still shows one Files row. Other Ubuntu Desktop applications stay in the menu.
