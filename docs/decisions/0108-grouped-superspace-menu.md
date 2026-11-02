# 0108. Grouped Super+Space menu

Date: 2026-11-02
Status: Accepted

## Context

`0030` kept submenu items out of the idle list and found them by typing, but the idle menu was still a flat alphabetical mix of parents (AI Agents, ROS, Power, Updates, Wallpaper, …) and normal apps. Omarchy’s Super+Space shows a short list of groups, drills in with Enter, goes up with Backspace when the filter is empty, and searches descendants of the active menu. Quickshell is not in the Ubuntu archive, and Corebrum does not vendor Omarchy.

## Decision

- Super+Space keeps the GTK launcher. The idle list is seven fixed groups from `/etc/corebrum/menu/corebrum-menu.json`: Apps, Learn, Robot, Appearance, Setup, Updates, and System.
- Enter on a group or static parent (ROS, AI Agents, RealSense, Corebrum Synapse, Learn, Updates, System) shows children in the same window. Backspace or Left with an empty search box goes up one level. Escape clears a non-empty filter, then quits.
- Typing searches descendants of the active menu. Nested hits show a short parent path. Empty filter shows only direct children.
- Updates rows and System power actions are `NoDisplay=true` desktop leaves, the same pattern as agent and ROS tool leaves, so typing `ubuntu` or `reboot` works from root. The Power parent desktop is named System.
- Dynamic choosers (Wallpaper, Ollama, Skills, Remote desktop, Wormhole, Autolock) still run their existing `open` path. Fuzzel remains the flat fallback when GTK cannot start.

## Consequences

`0030` still describes searchable submenu leaves. This decision adds root groups and in-window navigation. A desktop install that already ran needs `sudo corebrum install desktop` again so the menu tree and launcher replace the flat idle list.
