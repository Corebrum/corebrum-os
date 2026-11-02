# 0116. Super+Space marks submenu rows with >

Date: 2026-11-02
Status: Accepted

## Context

`0108` and `0111` open a group with Enter or Right. Leaf rows and parent rows looked the same, so operators could not tell which selection launched and which opened another level.

## Decision

- A row that `can_navigate` shows its label with a trailing ` >` in the GTK list and in `COREBRUM_LAUNCHER_LIST` output.
- Leaf rows keep the plain name. Search still matches the name without the marker.
- The marker is display-only. It does not change desktop entry `Name=` fields or Fuzzel fallback entries.

## Consequences

Root groups and parents such as ROS and AI Agents read as `Apps >` and `ROS >`. Choosing them still drills in. Getting Started and the keybindings list mention the marker.
