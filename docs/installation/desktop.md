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

That command also installs the base profile if it is not already present. It needs 12 GiB free on `/`. It enables `greetd` and sets the default target to `graphical.target` when that is not already the default. It does not start the greeter until the next boot. If the Ubuntu archive later contains `hyprland`, this command does not add the PPA.

## After a successful install

Reboot. The greeter is on VT 7 (`Ctrl+Alt+F7`). Log in with an existing user. Hyprland starts from `/usr/local/bin/corebrum-session` using `/etc/corebrum/hypr/hyprland.conf`.

| Key | Action |
| --- | --- |
| Super+Return | Kitty |
| Super+Q | Close the focused window |
| Super+F | Fullscreen |
| Super+V | Float or tile |
| Super+Space | Fuzzel launcher |
| Super+Alt+Space | App grid |
| Super+S | Agent scratchpad terminal |
| Super+1 … Super+5 | Workspaces |
| Super+Shift+1 … Super+Shift+5 | Move the window to a workspace |
| Super+Shift+E | Leave Hyprland and return to the greeter |
| Ctrl+Alt+F1 | Text console |

Waybar is the top bar: workspaces, window title, CPU, memory, network, and clock. The grid starts with Terminal, Files, and Browser. Add a robotics tool later by appending `Label|command` to `/etc/corebrum/dashboard/tiles.conf`. Do not put `|` or `#` in the command.

```bash
./scripts/validate/desktop.sh
```

That script checks packages, config files, that greetd is enabled, and that `Hyprland --verify-config` accepts `/etc/corebrum/hypr/hyprland.conf`. It does not prove the session tiled a window. After you log in, confirm Super+Return, two windows tiling, Super+1 and Super+2, Super+F, and that Waybar shows the clock. Then switch to VT 1 and back.

Firefox is Ubuntu's transitional snap package. Installing the desktop profile installs that snap.

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

This disables greetd, restores the previous default target when this installer changed it, restores the previous greetd config from the backup it recorded, deletes Corebrum files under `/etc/corebrum` and `/usr/local/bin`, and removes the Hyprland PPA source, pin, and key. It does not remove Hyprland, libinput, Waybar, Firefox, or other packages. Reboot afterward.

`./scripts/uninstall.sh --profile base` still refuses to remove the base packages.

## What is not done

Phase 2 is not accepted until a machine with an Ubuntu `hyprland` package boots to greetd, starts Hyprland, and passes the checks above. Quickshell, ROS 2, Zenoh, RViz, Gazebo, RealSense, AgenticROS, and Corebrum Mesh are not part of this install.
