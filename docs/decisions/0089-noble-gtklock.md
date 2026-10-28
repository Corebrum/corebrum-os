# 0089. Ubuntu 24.04 lock screen uses gtklock 4

Date: 2026-10-28
Status: Accepted

## Context

Decision 0088 locked Ubuntu 24.04 with `swaylock`. That program draws a ring on the wallpaper. It has no logo and no password field. The login screen is `corebrum-login`, and the Ubuntu 26.04 lock screen is gtklock 4: the Corebrum logo, a centered password field, and Unlock, with the time and date in the top right.

Ubuntu 24.04 publishes gtklock 2.1.0. Sway 1.9 locks through `ext-session-lock`, which gtklock gained in 3.0.0. The 2.1 package cannot take the place of swaylock. gtklock 4.0.0 and gtk-session-lock 0.2.0 are the same versions Ubuntu 26.04 packages.

## Decision

- Both releases lock with gtklock 4 and `/etc/corebrum/gtklock/config.ini`. Super+Escape no longer runs swaylock. A desktop install removes `/etc/corebrum/sway/swaylock.conf`.
- Ubuntu 26.04 still installs the archive `gtklock` package.
- Ubuntu 24.04 does not install that archive package. The desktop install builds gtk-session-lock 0.2.0 and gtklock 4.0.0 from the pinned GitHub tags, installs them under `/usr/local`, and writes `/etc/pam.d/gtklock` as `auth include login`. The checksums are in `manifests/versions/gtklock.txt`. A later install skips the build when `gtklock -v` already prints `gtklock v4.0.0` and the PAM file is present.
- The lock command uses `/usr/local/bin/gtklock` when that binary is version 4, and otherwise `/usr/bin/gtklock` when that binary is version 4.

## Consequences

Super+Escape on Ubuntu 24.04 shows the same logo, password field, Unlock button, and corner clock as Ubuntu 26.04. The account password and Enter, or Unlock, opens the session. The archive gtklock 2.1 package stays uninstalled. Jetson is still not part of this decision.
