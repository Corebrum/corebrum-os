# 0030. Super+Space search finds submenu items without listing them

Date: 2026-10-23
Status: Accepted

## Context

`0029` put each submenu item in the main Fuzzel list so typing `grok` or `gazebo` could find it. Fuzzel shows every visible desktop entry when the search box is empty, so Grok, Gazebo, and the other submenu rows sat in the main menu beside AI Agents and ROS. Fuzzel 1.12 also skips entries with `NoDisplay=true` while searching, so hiding those files does not keep them searchable inside Fuzzel itself.

## Decision

- The idle Super+Space list is the parent entries and the normal applications. AI Agents, ROS, RealSense, and Corebrum Synapse still open their submenus.
- Each submenu item is still a desktop file, with `NoDisplay=true`, so the idle list and the app grid omit it. The file is removed when that item leaves the submenu.
- The Super+Space window reads those files itself. An empty search box does not show them. Typing `grok`, `gazebo`, or another submenu name adds the matching row. Choosing it installs or launches that item, the same command the submenu runs.
- The window uses GTK and the layer shell. `python3-gi`, `gir1.2-gtk-3.0`, and `libgtk-layer-shell0` are desktop packages. Both noble and resolute publish them. If GTK cannot start, Super+Space falls back to Fuzzel with a blank prompt.
- Wallpaper images, autolock timers, the keybinding list, and Remote desktop start and stop stay inside their parent menus.

## Consequences

`0029` is superseded. A desktop install that already ran needs `sudo ./scripts/corebrum.sh install desktop` again so the new window and the hidden desktop files replace the flat list.
