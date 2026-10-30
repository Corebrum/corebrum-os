# 0100. Login and lock glitches follow the system clock

Date: 2026-10-30
Status: Accepted

## Context

The login screen and the lock screen each glitch for 1.2 seconds. That burst was the last part of a 40 second CSS loop, and the loop started when the screen appeared. Two machines on the same desk therefore glitched at different moments. See `docs/decisions/0097-lock-glitch.md` and `docs/decisions/0098-login-glitch.md`.

The machines already keep their clocks aligned with NTP. A CSS animation runs on the toolkit's monotonic clock, so a negative delay chosen at startup would drift away from the wall clock and would not come back.

gtklock 4.0.0 can load a module. `on_window_create` receives the lock window. The module exports `module_major_version` 4 and `module_minor_version` 0, which is the version gtklock 4.0.0 accepts. The second field of its window struct is the `GtkWidget`.

## Decision

- The burst still lasts 1.2 seconds. It starts at each minute and each half-minute of the machine's local clock. A screen that appears within 200 milliseconds of that mark joins the burst. Otherwise it waits for the next one.
- `corebrum-login` adds the `glitch` class for 1.5 seconds, then reads the clock again. The gtklock module `libcorebrum-glitch.so` does the same on the lock window. The class plays the one-shot animations. The username, password, and Unlock rules are not in those animations.
- The desktop install compiles the module with the system `gcc` and `libgtk-3-dev` and writes `/usr/local/lib/corebrum/libcorebrum-glitch.so`. `/etc/corebrum/gtklock/config.ini` loads that path. Uninstall removes the file.
- Login and the module share the same period, burst, grace, and clear times.

## Consequences

After `sudo corebrum install desktop`, the next Super+Escape and the next greetd start glitch on the local minute and half-minute. Machines in the same time zone with synchronized clocks glitch together. A lock or login that is already up keeps the previous timing until the next one.
