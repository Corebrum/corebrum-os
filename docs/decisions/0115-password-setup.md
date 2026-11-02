# 0115. Setup Password runs passwd in a terminal

Date: 2026-11-02
Status: Accepted

## Context

Login and gtklock use the Linux account password. Operators may not know to open a terminal and run `passwd`. Omarchy exposes that under Update → Password → User. Corebrum Updates stays software-only. GNOME’s Users panel cannot run under Sway.

## Decision

- Super+Space Setup lists Password after Timezone.
- Choosing it opens Kitty and runs `passwd` for the logged-in user. Closing the terminal cancels an unfinished prompt.
- There is no root, other-user, disk-encryption, or passwordless-sudo row.
- GNOME Control Center is not used.

## Consequences

Typing password or passwd at Super+Space finds the row. A successful change updates the same credential login and lock already use. Remote desktop keeps its own VNC password from that menu.
