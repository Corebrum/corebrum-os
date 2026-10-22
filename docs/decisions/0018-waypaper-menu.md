# 0018. Waypaper is a Super+Space install

Date: 2026-10-22
Status: Accepted

## Context

The operator asked for [Waypaper](https://github.com/anufrievroman/waypaper) on Super+Space. Waypaper 2.9 is the current PyPI release. It requires Python newer than 3.10 and PyGObject. This machine has Python 3.14. Ubuntu 26.04 does not publish a `waypaper` package. It does publish `pipx` 1.8.0, `python3-gi`, GTK 3, and `swaybg` 1.2.1. `swaybg` is already installed here and is the only Waypaper backend present. `hyprpaper` 0.8.3 is in the archive and is not installed. `swww` and `mpvpaper` are not in the archive.

Waypaper is a chooser. `swaybg` draws the image on the background layer, over Hyprland's own wallpaper and under the Corebrum tagline. A `pipx` install without `--system-site-packages` cannot import the system `gi` module. Waypaper saves the chosen image in `~/.config/waypaper/config.ini` when the user sets one. Its package also ships a desktop file, and `pipx` leaves that file inside the virtualenv, so Super+Space does not list it.

## Decision

- Super+Space shows `Waypaper   install` until `~/.local/bin/waypaper` exists, then `Waypaper`. Choosing the install row runs, in a terminal and as the logged-in user, `sudo apt-get install -y pipx swaybg python3-gi python3-gi-cairo gir1.2-gtk-3.0` and `pipx install --system-site-packages 'waypaper==2.9'`. Choosing the installed row executes `~/.local/bin/waypaper`.
- The desktop profile does not install Waypaper, `pipx`, or `swaybg` ahead of that choice. The menu does not write `~/.config`.
- On later logins, the session runs `waypaper --restore` only when both `~/.local/bin/waypaper` and `~/.config/waypaper/config.ini` already exist.

## Consequences

The first use opens the Waypaper window. `swaybg` accepts PNG and JPEG, which covers the Hyprland wallpaper files. A second desktop install does not remove a Waypaper install under `~/.local`. Uninstall removes the menu script and leaves the user's `pipx` install in place.
