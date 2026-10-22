# 0019. Super+Space lists the Super keybindings

Date: 2026-10-22
Status: Accepted

## Context

The operator asked for a Super+Space entry that lists and explains the Super shortcuts. Those shortcuts live in `/etc/corebrum/hypr/hyprland.conf`. The key table in `docs/installation/desktop.md` also includes Print and Ctrl+Alt+F1, which are not Super shortcuts.

## Decision

- Super+Space shows `Keybindings`. Choosing it opens a Fuzzel list of every Super shortcut: what to press, then what it does. Choosing a row closes the list.
- The list covers terminal, Firefox, close, fullscreen, float, this menu, the app grid, the agent scratchpad, lock, leave the session, clipboard, screen recording, focus movement, and workspaces.
- Volume, brightness, Print without Super, and the text console are not on this list.

## Consequences

A new Super shortcut has to be added to both the Hyprland config and `corebrum-keys-menu`. The menu does not write `~/.config`.
