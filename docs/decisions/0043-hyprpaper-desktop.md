# 0043. hyprpaper is part of the desktop install

Date: 2026-10-25
Status: Accepted

## Context

Decision 0020 made Super+Space show `Wallpaper   install` until `hyprpaper` was on `PATH`. Choosing that row installed the Ubuntu package, then disabled `hyprpaper.service`. Ubuntu 24.04 has no `hyprpaper` candidate, so that row could not finish there. The desktop profile did not install the package.

On 2026-10-25 Ubuntu 26.04 publishes `hyprpaper` 0.8.3-1 in universe. Ubuntu 24.04 still does not. `ppa:cppiber/hyprland` for noble publishes `hyprpaper` 0.8.4-1ppa3. That package depends on `libhyprtoolkit6` (>= 0.6.0), and the same PPA publishes `libhyprtoolkit6` 0.6.0-1ppa3. Noble does not publish `libhyprtoolkit6`. The other dependencies are already in `manifests/packages/hyprland-ppa.txt` or in the Ubuntu archive.

The packaged user service runs `/usr/bin/hyprpaper` with no config path. This session starts `hyprpaper --config` only after an image is chosen.

## Decision

- The desktop profile installs `hyprpaper`. On resolute it installs the Ubuntu archive package. On noble, where that package is absent, it installs `hyprpaper` from `ppa:cppiber/hyprland`. `hyprpaper` and `libhyprtoolkit6` are pinned with the other packages from that archive.
- The desktop install disables `hyprpaper.service` for every user. The drop-in that replaces its start command stays in place, including after a later package upgrade enables the unit again.
- Super+Space lists `Wallpaper`. Choosing it lists the Corebrum wallpapers in `/usr/share/hypr` and images in `~/Pictures` and `~/Pictures/Wallpapers`. The choice is written to `${XDG_STATE_HOME:-~/.local/state}/corebrum/hyprpaper.conf` with `splash = false` and `monitor = *`. The menu does not install a package and does not write `~/.config`.
- `hyprpaper` stays out of `manifests/packages/desktop.txt`, because that list is the Ubuntu 24.04 archive. Uninstall still leaves the package installed.

## Consequences

A new desktop install can change the session wallpaper from Super+Space without a separate package install. Login and lock still use `/usr/share/hypr/wall2.png`. The session does not start `hyprpaper` until an image has been chosen. This replaces the install-on-demand rule in decision 0020.
