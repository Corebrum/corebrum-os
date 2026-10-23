# 0022. Autolock and stay awake

Date: 2026-10-23
Status: Accepted

## Context

Super+Escape locks the screen with `hyprlock`. Nothing locks it when the session is left idle. Ubuntu 26.04 publishes `hypridle` 0.1.7, which listens for idle and for systemd idle inhibitors. Ubuntu 24.04 does not publish `hypridle` or `hyprlock`. The `hypridle` package enables a user service that runs `hypridle` with no config path, so it would read `~/.config/hypr/hypridle.conf`.

## Decision

- When the archive has both `hypridle` and `hyprlock`, the desktop profile installs `hypridle`. Ubuntu 24.04 skips it. It is not listed in `manifests/packages/desktop.txt`.
- The session starts `hypridle --config` with `/etc/corebrum/hypr/hypridle.conf`, or with the saved timer when one exists. hypridle 0.1.7 also requires `/etc/xdg/hypr/hypridle.conf` to exist during startup, so that path is a symlink to the Corebrum file. The default timer is 10 minutes. Idle runs `loginctl lock-session`, and hypridle's lock command is `/usr/local/bin/corebrum-lock`. The screen also locks before sleep.
- Super+Space shows Autolock. The list is Stay awake, 5 minutes, 10 minutes, 30 minutes, and 1 hour. The current row is marked `on`. A saved timer is written under the user's state directory, not `~/.config`.
- Stay awake runs `systemd-inhibit --what=idle` until it is turned off or the session ends. Super+Shift+Escape toggles it. hypridle is told not to ignore systemd or D-Bus idle inhibitors, so a video that asks to stay awake still pauses the timer.
- A systemd drop-in makes the packaged user service exit without starting hypridle. The install also disables that service.

## Consequences

The first login on Ubuntu 26.04 locks after 10 minutes of idle. Stay awake lasts only for the current session. Ubuntu 24.04 still locks only with Super+Escape. Uninstall removes the menu, the config, and the service drop-in, and leaves the `hypridle` package installed.
