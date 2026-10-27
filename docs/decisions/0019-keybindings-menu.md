# 0019. Super+Space lists the Super keybindings

Date: 2026-10-22
Status: Accepted

## Context

The operator asked for a Super+Space entry that lists and explains the Super shortcuts. Those shortcuts live in `/etc/corebrum/hypr/hyprland.conf`. The key table in `docs/installation/desktop.md` also includes Print and Ctrl+Alt+F1, which are not Super shortcuts.

## Decision

- Super+Space shows `Keybindings`. Choosing it opens a Fuzzel list of every Super shortcut: what to press, then what it does. Choosing a row closes the list.
- The list covers terminal, Firefox, Files, Text Editor, close, fullscreen, float, this menu, the app grid, the agent scratchpad, lock, leave the session, clipboard, screen recording, focus movement, and workspaces. Super+Shift+N runs `gnome-text-editor`. See `docs/decisions/0039-text-editor.md`.
- Super+Space lists the file manager as `Files`. The launcher writes that name over the Thunar desktop entry for the menu only. Super+Shift+F runs `thunar`.
- Super+Space lists `nm-connection-editor` as `Network Configuration`. The launcher writes that name over Ubuntu's `Advanced Network Configuration` entry. The idle list is sorted by name, so the row sits with the other N entries.
- Volume, brightness, Print without Super, and the text console are not on this list.
- Super+P copies a selected area, Super+Shift+P copies the whole screen, Super+Alt+P records a selected area, and Super+Alt+Shift+P stops that recording. Those four shortcuts run the same commands as Print, Shift+Print, Super+Print, and Super+Shift+Print. The record shortcuts ask whether to include the default microphone, a webcam, or the RealSense color camera when each is available. See `docs/decisions/0040-record-camera.md`.

## Consequences

A new Super shortcut has to be added to both the Hyprland config and `corebrum-keys-menu`. The menu does not write `~/.config`.
