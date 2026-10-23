# 0025. Hyprland starts through its watchdog and dialog helper

Date: 2026-10-23
Status: Accepted

## Context

Hyprland 0.53 draws two warnings when the session begins. One says `hyprland-guiutils` is missing. The check looks for the `hyprland-dialog` executable, which Ubuntu publishes in `hyprland-qtutils` 0.1.5. There is no package named `hyprland-guiutils`. The other warning says Hyprland was started without `start-hyprland`. That helper is the watchdog shipped in `/usr/bin/start-hyprland`, and the packaged session file runs it. Corebrum starts Hyprland from `corebrum-session` so the session uses `/etc/corebrum/hypr/hyprland.conf` and the system profile scripts.

Ubuntu 24.04 does not publish `hyprland-qtutils`. The pinned Hyprland PPA is not a source for it.

## Decision

- `corebrum-session` runs `start-hyprland -- --config /etc/corebrum/hypr/hyprland.conf` when `start-hyprland` is installed. Arguments after `--` are passed to Hyprland. A build without that helper still runs `Hyprland --config` directly.
- The desktop profile installs `hyprland-qtutils` only when `apt-cache policy` shows a candidate from `archive.ubuntu.com` or `security.ubuntu.com`.

## Consequences

The next login on Ubuntu 26.04 does not show those two warnings. Dialogs that Hyprland opens through `hyprland-dialog` can run. Ubuntu 24.04 keeps the direct `Hyprland` start when its package has no `start-hyprland`, and it does not gain the dialog helper. Uninstall leaves the `hyprland-qtutils` package installed.
