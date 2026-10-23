# 0028. Super+C, Super+X, and Super+V copy, cut, and paste

Date: 2026-10-23
Status: Accepted

## Context

The operator asked for Super+C, Super+X, and Super+V to copy, cut, and paste text in every application, including a terminal. Those two Super keys already did something else: Super+C opened clipboard history, and Super+V floated the focused window. In a terminal, Ctrl+C interrupts the running program, and Kitty's copy and paste chords are Ctrl+Shift+C and Ctrl+Shift+V.

## Decision

- Super+C copies, Super+X cuts, and Super+V pastes in the focused window. Hyprland sends Ctrl+C, Ctrl+X, or Ctrl+V to an ordinary application.
- The same keys send Ctrl+Shift+C, Ctrl+Shift+X, or Ctrl+Shift+V when the focused window is a terminal. Kitty maps Ctrl+Shift+X to copy the selection and clear it. Ctrl+C in a terminal still interrupts the program.
- Clipboard history moves to Super+Shift+C. Float or tile moves to Super+T.
- The key list in Super+Space and the desktop shortcut table use these keys.

## Consequences

A terminal that was already open keeps Kitty's previous shortcuts until it is opened again, so Super+X starts cutting in that window after it restarts. Super+C and Super+V work in the current Kitty because Ctrl+Shift+C and Ctrl+Shift+V are already its copy and paste keys. Another terminal receives the Ctrl+Shift chords; cut does something only when that terminal binds Ctrl+Shift+X.
