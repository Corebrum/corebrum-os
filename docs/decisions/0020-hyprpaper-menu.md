# 0020. Wallpaper is a hyprpaper image list

Date: 2026-10-22
Status: Superseded by docs/decisions/0043-hyprpaper-desktop.md

## Context

Waypaper's window was harder to use than a list of images. Decision 0018 added it as a Super+Space install. Ubuntu 26.04 publishes `hyprpaper` 0.8.3. That package draws a wallpaper inside a running Hyprland session and can be pointed at one image with `--config`. Ubuntu 24.04 still has no `hyprpaper` candidate, as recorded in decision 0005. `hyprpaper` cannot draw the login or lock screen.

Installing the package also enables `hyprpaper.service` for every graphical user session. That unit runs `/usr/bin/hyprpaper` with no config path, so it reads `~/.config/hypr/hyprpaper.conf` and leaves splash text on. This session already turns Hyprland's own splash off.

## Decision

- Super+Space shows `Wallpaper   install` until `hyprpaper` is on `PATH`, then `Wallpaper`. Choosing the install row installs the Ubuntu `hyprpaper` package when apt has a candidate, then disables the package's user service. On Ubuntu 24.04 the row reports that the archive has no package.
- Choosing an installed row lists the Corebrum wallpapers in `/usr/share/hypr` and images in `~/Pictures` and `~/Pictures/Wallpapers`. The choice is written to `${XDG_STATE_HOME:-~/.local/state}/corebrum/hyprpaper.conf` with `splash = false` and `monitor = *`. hyprpaper 0.8.3 ignores a wallpaper block whose monitor name is empty, and it treats quotation marks as part of the image path. The menu does not write `~/.config`.
- The desktop profile does not install `hyprpaper`. A systemd drop-in makes the packaged user service exit without drawing, including after a later package upgrade enables it again. The session starts `hyprpaper --config` only when that state file already exists.
- The Waypaper menu is removed. A Waypaper install already present under `~/.local` is left in place, and the session no longer runs `waypaper --restore`.

## Consequences

The first chosen image replaces the session wallpaper, and the next login keeps it. Login and lock use `/usr/share/hypr/wall2.png`, which the desktop install replaces with the Corebrum image. See `docs/decisions/0024-corebrum-wallpapers.md`. The tagline stays on the bottom bar. Uninstall removes the menu and the service drop-in, and leaves an installed `hyprpaper` package and any Waypaper install under `~/.local`.
