# 0132. Auto dim and battery wake display

Date: 2026-11-09
Status: Accepted

## Context

Operators asked to save battery on laptops and mobile robots without suspend or hibernate, which can break USB sensors after wake. Autolock already runs `swayidle` for security. A separate idle timer should blank the panel while ROS and peripherals keep running.

`corebrum-battery-notify` already sends one critical Mako popup at about 10% while discharging (`docs/decisions/0128-battery-low-notification.md`). A dimmed screen could hide that warning.

## Decision

- Super+Space Setup lists **Auto dim**, independent of Autolock. The default is **Off**. The other rows are 5 minutes, 10 minutes, 30 minutes, and 1 hour. The current row is marked `on`. Choosing a time saves it under the user state directory and restarts idle handling. Stay awake on Autolock still pauses `swayidle`, so auto dim pauses with it.
- `/usr/local/bin/corebrum-swayidle` runs one `swayidle` process. It always applies the Autolock timeout. When Auto dim is not Off, it adds an earlier or later `timeout` that runs `/usr/local/bin/corebrum-display-dim off` with a matching `resume` on that same timeout line (`swayidle` only accepts resume there). The Autolock timeout gets the same resume when Auto dim is on so a lit gtklock is visible after a longer idle. Activity runs `corebrum-display-dim on`, which turns DPMS on and restores backlight when `brightnessctl` works.
- Auto dim shares the swayidle install path with Autolock (`corebrum-swayidle install-script`).
- When the battery notifier fires at or below the threshold while discharging, it runs `corebrum-display-dim on` before the critical `notify-send`, so the operator sees the popup on a lit display.

## Consequences

`corebrum-lock idle` defers gtklock while the panel is dimmed: it writes `pending-autolock` and leaves the display off. The next `corebrum-display-dim on` from swayidle resume wakes the panel and then starts gtklock. Manual Super+Escape still wakes first and locks immediately. While gtklock is up or logind reports the session locked, auto dim does not turn the panel off. Machines without backlight control still get DPMS off. Uninstall removes the new commands with the other desktop paths.
