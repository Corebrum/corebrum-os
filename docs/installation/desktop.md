# Hyprland desktop

Phase 2 adds a keyboard-driven Wayland session on top of the base profile: Hyprland with dwindle tiling, Waybar, Kitty, Fuzzel, an app grid, Thunar, Firefox, Mako, and a greetd login.

The greeter is `agreety`, the text greeter shipped inside Ubuntu's `greetd` package. `tuigreet` is not in Ubuntu 24.04. Quickshell is not either, so the bar and launcher are Waybar and Fuzzel, and the app grid is `corebrum-grid`.

## Hyprland source

Ubuntu 24.04 does not publish `hyprland`. The desktop profile then adds `ppa:cppiber/hyprland`, checks that the signing key fingerprint is `A54D23B62FF3FCC76EFF71E8FDBAAA1CF0CCF48E`, and pins that archive. Only Hyprland and the libraries listed in `manifests/packages/hyprland-ppa.txt` are installed from it. That list includes newer `libinput10` and `libxkbcommon0` than Ubuntu 24.04 ships, because Hyprland 0.56.2 requires them. Waybar, Fuzzel, and PipeWire stay on the Ubuntu archive. The decision is `docs/decisions/0006-hyprland-ppa.md`.

Quickshell is still not in Ubuntu 24.04, so the bar and launcher are Waybar and Fuzzel.

Preview the plan without changing the system:

```bash
./scripts/install.sh --profile desktop --dry-run
```

The dry-run prints the PPA, the pin, and the package list. It exits 0.

Apply it with:

```bash
sudo ./scripts/install.sh --profile desktop
```

The same install from the checkout is `sudo ./scripts/corebrum.sh install desktop`. After the command is linked, that is `sudo corebrum install desktop`. See `docs/installation/cli.md`.

That command also installs the base profile if it is not already present. It needs 12 GiB free on `/`. It enables `greetd` and sets the default target to `graphical.target` when that is not already the default. It does not start the greeter until the next boot. If the Ubuntu archive later contains `hyprland`, this command does not add the PPA.

When the archive publishes `hyprland-backgrounds`, the same command installs it. That package holds the default Hyprland wallpaper. Ubuntu 26.04 splits it out of `hyprland`, and `--no-install-recommends` does not pull it in otherwise. Ubuntu 24.04 does not publish it. Hyprland loads the image at session start, so a desktop that is already running shows it after the next login.

## After a successful install

Reboot. The greeter is on VT 7 (`Ctrl+Alt+F7`). Log in with an existing user. Hyprland starts from `/usr/local/bin/corebrum-session` using `/etc/corebrum/hypr/hyprland.conf`.

| Key | Action |
| --- | --- |
| Super+Return | Kitty |
| Super+Q | Close the focused window |
| Super+F | Fullscreen |
| Super+V | Float or tile |
| Super+Space | Fuzzel launcher. ROS 2 is listed there as `ROS 2   install` until `corebrum install ros` has been run, then as `ROS` |
| Super+Alt+Space | App grid |
| Super+S | Agent scratchpad terminal |
| Super+1 … Super+5 | Workspaces |
| Super+Shift+1 … Super+Shift+5 | Move the window to a workspace |
| Super+Shift+E | Leave Hyprland and return to the greeter |
| Print | Copy a selected area |
| Super+C | Clipboard history |
| Ctrl+Alt+F1 | Text console |

Waybar is the top bar: workspaces, window title, CPU, memory, network, and clock. The grid starts with Terminal, Files, and Browser. Add a robotics tool later by appending `Label|command` to `/etc/corebrum/dashboard/tiles.conf`. Do not put `|` or `#` in the command.

```bash
./scripts/validate/desktop.sh
```

That script checks packages, config files, that greetd is enabled, and that `Hyprland --verify-config` accepts `/etc/corebrum/hypr/hyprland.conf`. It does not prove the session tiled a window. After you log in, confirm Super+Return, two windows tiling, Super+1 and Super+2, Super+F, and that Waybar shows the clock. Then switch to VT 1 and back.

Firefox is Ubuntu's transitional snap package. Installing the desktop profile installs that snap.

## Node.js

The desktop profile installs Node.js 26.x, the npm that ships with that build, and pnpm. nvm `v0.40.8` lives at `/usr/local/nvm`. Ubuntu 26.04 publishes Node.js 22, so this does not come from apt and it does not add a repository. The decision is `docs/decisions/0012-node-nvm.md`.

A Corebrum terminal is a login shell, so `node`, `npm`, `pnpm`, and `nvm` are on `PATH`. The installer does not write `~/.nvm` or `~/.bashrc`. A terminal that was already open before the install picks them up the next time it starts. Installing another Node version with `nvm install` needs root, because the checkout is root-owned. A second desktop install leaves an existing Node 26.x and an existing pnpm in place.

## Recovery

From the text console on VT 1:

```bash
sudo systemctl disable greetd.service
sudo systemctl set-default multi-user.target
sudo reboot
```

A broken Hyprland config sends you back to the greeter, because greetd restarts `agreety` when the session exits. Edit `/etc/corebrum/hypr/hyprland.conf` from VT 1. The previous greetd config, if the installer replaced one, is under `/var/log/corebrum/backups/`.

## Removal

```bash
sudo ./scripts/uninstall.sh --profile desktop
```

This disables greetd, restores the previous default target when this installer changed it, restores the previous greetd config from the backup it recorded, deletes Corebrum files under `/etc/corebrum` and `/usr/local/bin`, and removes the Hyprland PPA source, pin, and key. When `/usr/local/nvm/.corebrum-managed` is present it also removes that nvm checkout and the Node.js block in `/etc/bash.bashrc`. It does not remove Hyprland, libinput, Waybar, Firefox, or other packages. Reboot afterward.

`./scripts/uninstall.sh --profile base` still refuses to remove the base packages.

## What is not done

The operator continued to Phase 3 after this machine booted to Hyprland and showed Waybar. Confirm the key table above on the session if that has not been done. Workstation services are documented in `docs/installation/services.md`. Quickshell, ROS 2, Zenoh, RViz, Gazebo, RealSense, AgenticROS, and Corebrum Mesh are not part of this install.
