# 0082. gtklock password field

Date: 2026-10-28
Status: Accepted

## Context

Super+Escape locked with `swaylock` 1.8.4-1. That locker draws a ring. It has no password field and no label. The account password still unlocks it, and the ring is the only control.

Ubuntu resolute publishes `gtklock` 4.0.0-1build1 in universe on amd64 and on arm64. `gtklock` 4.0.0 uses `ext-session-lock` through `libgtk-session-lock0` 0.2.0-3. Its form has a Password label, a password entry, and an Unlock button. `--config` reads one file. When that path is set, gtklock does not read `~/.config/gtklock`.

## Decision

- The desktop profile installs `gtklock` when the archive has a candidate. It does not install `swaylock`. A `swaylock` package already on the machine stays installed.
- Super+Escape runs `gtklock --config /etc/corebrum/gtklock/config.ini`. The background is `/usr/share/hypr/wall2.png`. The style is `/etc/corebrum/gtklock/style.css`. The password entry sits in a dark card with a teal border. The form is visible when the screen locks. `follow-focus` is on, so the field follows the pointer across monitors. Decision 0083 draws `/usr/share/corebrum/logo.png` above that form.
- The lock wrapper still exports the vc4 device on a Raspberry Pi. `gtklock` is a client of the running Sway session.
- Autolock still runs `/usr/local/bin/corebrum-lock`. Choosing Autolock when `swayidle` is missing installs `swayidle` and `gtklock`.
- A desktop install removes `/etc/corebrum/sway/swaylock.conf`.

## Consequences

After `sudo corebrum install desktop`, Super+Escape shows the password field. The account password and Enter, or Unlock, opens the session. A wrong password clears the field and says login failed. A machine that still has the previous `corebrum-lock` keeps the ring until that install copies the new command.
