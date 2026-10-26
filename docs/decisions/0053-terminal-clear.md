# 0053. Super+K clears the terminal

Date: 2026-10-26
Status: Accepted

## Context

Super+H, Super+J, Super+K, and Super+L moved focus left, down, up, and right. Super+Left, Super+Down, Super+Up, and Super+Right already do that. Super+Shift plus those letters swapped the focused tile the same way Super+Shift+Arrows do. The operator asked to use the letter keys for something else, and to clear the terminal with Super+K the way macOS Terminal clears with Command+K.

Kitty names that macOS shortcut Clear to start. The action is `clear_terminal to_cursor active`: the screen clears to the prompt when shell integration is on, and the scrollback is erased. Corebrum's terminal is Kitty with `shell bash --login`. Kitty's shell integration stays enabled for that shell.

## Decision

- Super+Arrows move focus. Super+Shift+Arrows swap the focused tile.
- Super+H, Super+J, Super+L, and Super+Shift with H, J, K, or L are not bound.
- Super+K runs `corebrum-edit-keys clear`. In a terminal it sends Ctrl+Shift+K. Kitty maps that chord to `clear_terminal to_cursor active`. Another window does nothing.
- The Keybindings list and the desktop shortcut table include Super+K. They list the arrow keys for focus and for swapping tiles.

## Consequences

A Kitty window that is already open keeps its previous shortcuts until it is opened again, so Super+K clears that window after it restarts. Super+K in another terminal sends Ctrl+Shift+K, and that terminal clears only when it binds the same chord.
