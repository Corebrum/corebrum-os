# 0108. Grouped Super+Space menu

Date: 2026-11-02
Status: Accepted

## Context

`0030` kept submenu items out of the idle list and found them by typing, but the idle menu was still a flat alphabetical mix of parents (AI Agents, ROS, Power, Updates, Wallpaper, …) and normal apps. Omarchy’s Super+Space shows a short list of groups, drills in with Enter, goes up with Backspace when the filter is empty, and searches descendants of the active menu. Quickshell is not in the Ubuntu archive, and Corebrum does not vendor Omarchy.

## Decision

- Super+Space keeps the GTK launcher. The idle list is eight fixed groups from `/etc/corebrum/menu/corebrum-menu.json`: Apps, Learn, AI Agents, Robot, Appearance, Setup, Updates, and System. The AI Agents root node uses **`navigateAs`: `corebrum-agents`** so one Enter opens the `corebrum-agent-*` list (Super+A default rows and each CLI) without a duplicate “AI Agents” submenu. GTK navigate lists only `corebrum-agent-*` desktop files for that id. See `docs/decisions/0131-ollama-ai-agents-menu.md` for Ollama in that same list.
- Enter or Right on a group or static parent (ROS, AI Agents, RealSense, Corebrum Synapse, Learn, Updates, System) shows children in the same window. Right only opens a submenu; it does not launch a leaf. Backspace or Left with an empty search box goes up one level. Escape clears a non-empty filter, then quits.
- Typing searches descendants of the active menu. Nested hits show a short parent path. Empty filter shows only direct children.
- Updates rows and System power actions are `NoDisplay=true` desktop leaves, the same pattern as agent and ROS tool leaves, so typing `ubuntu` or `reboot` works from root. The Power parent desktop is named System.
- **Choosers** in the menu tree (`Autolock`, `Autodim`, and `Voice`) list their rows with `lines` or `labels` and apply a choice with `pick` so Enter or Right opens the list in the GTK window; Left or Backspace goes back without running a row. Other dynamic parents (Wallpaper, Ollama, Skills, Remote desktop, Wormhole) still run their existing `open` path and Fuzzel. Fuzzel remains the flat fallback when GTK cannot start.

## Consequences

`0030` still describes searchable submenu leaves. This decision adds root groups and in-window navigation. A desktop install that already ran needs `sudo corebrum install desktop` again so the menu tree and launcher replace the flat idle list.
