# 0002. Omarchy shell on Ubuntu

Date: 2026-10-22
Status: Accepted

## Context

Corebrum OS is inspired by [Omarchy](https://github.com/omacom/omarchy) (`quattro`). That system is keyboard-first: Hyprland dwindle tiling, a Quickshell menu (`Super+Space`), an app grid (`Super+Alt+Space`), a dock, themes, and a scratchpad (`Super+S`). The Corebrum build plan also names Waybar, Fuzzel, and Kitty, which match an earlier Omarchy desktop.

Physical AI tools need a visible place to start: ROS 2, RViz, Gazebo, cameras, Zenoh, and later Corebrum Synapse and Corebrum Mesh.

## Decision

The Corebrum session will follow current Omarchy:

- Hyprland tiles windows. Dwindle is the default. Scrolling and floating layouts are per workspace.
- The app grid and dock are the tile interface. Robotics tools are declarative grid entries, not hardcoded buttons.
- A scratchpad workspace is reserved for an agent or robot terminal.
- Kitty is the first terminal. Ghostty stays optional.
- Quickshell is the preferred shell. Phase 2 must verify a Quickshell package or a pinned build for Ubuntu 24.04 before it is installed. If that check fails, Waybar and Fuzzel are the fallback and an app grid is still required.
- Omarchy branding, commercial defaults, and source are not vendored. A later phase that copies an MIT-licensed Omarchy file must keep its copyright notice.

## Consequences

`apps/dashboard/` will hold the grid manifest in a later phase. Sprint 1 does not install a compositor or a shell. Phase 2 cannot assume Quickshell exists in the Ubuntu archive.
