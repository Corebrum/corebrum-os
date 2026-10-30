# 0097. Lock screen glitch

Date: 2026-10-30
Status: Accepted

## Context

Super+Escape locks with gtklock 4. The picture is the wallpaper, the Corebrum logo, a centered password field, and the clock in the top right. That picture sits still until the clock changes.

gtklock 4.0.0 links GTK 3. Ubuntu 24.04 builds that version and this machine has GTK 3.24.41. Ubuntu 26.04 publishes gtklock 4.0.0-1build1, built against `libgtk-3-dev`, and `libgtk-3-0t64` 3.24.52. Both releases load `/etc/corebrum/gtklock/style.css` through the GTK 3 CSS provider. A parse error drops the whole file, including the password field. GTK 3 has no `transform` property. A keyframe rule cannot list two percentages in one block. Opacity, color, margin, and `background-position` do animate.

## Decision

- About every 40 seconds the lock screen glitches for under a second. Scan lines, a short tint, and four colored bars appear and jump. The logo image shifts inside its box. The clock and the date shift a few pixels and change color.
- The logo is its own box above the password card. The card is not part of the animation, so the field and Unlock stay still.
- The glitch widgets are overlay children with `pass-through` set. Clicks reach the password field.
- The same layout and style are installed on Ubuntu 24.04 and Ubuntu 26.04. The style uses only GTK 3.24 CSS.

## Consequences

After `sudo corebrum install desktop`, the next Super+Escape plays the glitch. The account password and Enter, or Unlock, still opens the session. A lock screen that is already up keeps the previous style until the next lock.
