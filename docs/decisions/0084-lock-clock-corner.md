# 0084. Lock screen clock in the top right

Date: 2026-10-28
Status: Accepted

## Context

The previous lock screen was hyprlock. Its time label used `$TIME` at 90pt, aligned to the top right with a 30px inset. The date under it used `date +"%A, %d %B %Y"` at 25px, with the same right inset. Decision 0082 switched the lock to gtklock. gtklock draws the clock and the date in the centered column, above the password field, and shrinks them while that field is focused.

## Decision

- `/etc/corebrum/gtklock/layout.ui` replaces gtklock's built-in layout. The time and date are an overlay aligned to the top and the right, 30px from those edges. The logo and the password field stay centered.
- The time format is `%H:%M`. The date format is `%A, %d %B %Y`. The clock stays 90pt and the date stays 25px while the password field is focused.
- The layout file is installed with the gtklock config. It is not copied into a home directory.

## Consequences

After `sudo corebrum install desktop`, the next Super+Escape shows the time and date in the top right. The password field and the logo stay in the center.
