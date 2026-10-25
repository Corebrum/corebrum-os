# Hyprland desktop

Phase 2 adds a keyboard-driven Wayland session on top of the base profile: Hyprland with dwindle tiling, Waybar, Kitty, Fuzzel, an app grid, Thunar, Firefox, GNOME Text Editor, Mako, and a greetd login.

On Ubuntu 26.04 the greeter is `gtkgreet` inside `cage`, with `/usr/share/hypr/wall2.png` behind the login box. The Corebrum logo sits above the clock and the login card. The first screen asks for the username. The password is the next screen. The session dropdown is hidden. Super+Escape locks the screen with `hyprlock`, and the same logo sits above the password field. Ubuntu 24.04 does not publish `gtkgreet` or `hyprlock`, so that release keeps `agreety`, the text greeter inside `greetd`. `tuigreet` is not in Ubuntu 24.04. Quickshell is not either, so the bar and launcher are Waybar and Fuzzel, and the app grid is `corebrum-grid`. The decisions are `docs/decisions/0015-hyprlock-gtkgreet.md` and `docs/decisions/0037-login-lock-logo.md`.

## Hyprland source

Ubuntu 24.04 does not publish `hyprland`. The desktop profile then adds `ppa:cppiber/hyprland`, checks that the signing key fingerprint is `A54D23B62FF3FCC76EFF71E8FDBAAA1CF0CCF48E`, and pins that archive. Only Hyprland and the libraries listed in `manifests/packages/hyprland-ppa.txt` are installed from it. That list includes newer `libinput10` and `libxkbcommon0` than Ubuntu 24.04 ships, because Hyprland 0.56.2 requires them. Waybar, Fuzzel, and PipeWire stay on the Ubuntu archive. The decision is `docs/decisions/0006-hyprland-ppa.md`.

Quickshell is still not in Ubuntu 24.04, so the bar is Waybar. Super+Space is a GTK window: the idle list keeps parent menus such as AI Agents and ROS, and typing `grok` or `gazebo` adds that submenu item. Fuzzel still opens the submenus. The desktop packages are `python3-gi`, `gir1.2-gtk-3.0`, and `libgtk-layer-shell0`. See `docs/decisions/0030-menu-search-submenus.md`.

The same profile installs Ubuntu `espeak-ng-espeak`. That package depends on `espeak-ng` and provides the `espeak` command. Noble publishes 1.51+dfsg-12build1 and resolute publishes 1.52.0+dfsg-5build1. Speech recognition and `corebrum speak` are not part of this install. See `docs/decisions/0031-espeak-ng.md`.

The same profile installs Ubuntu `gnome-text-editor`. Noble publishes 46.3-0ubuntu2 and resolute publishes 50.1-0ubuntu0.1. Super+Space lists that application as Text Editor. Typing `notepad` finds the same row. See `docs/decisions/0039-text-editor.md`.

The same profile installs Ubuntu GStreamer so `agenticros desktop` can send the screen to AgenticROS Cloud: `gstreamer1.0-tools`, `gstreamer1.0-plugins-base`, `gstreamer1.0-plugins-good`, `gstreamer1.0-plugins-ugly`, and `gstreamer1.0-pipewire`. The ugly plugins package supplies `x264enc`. PipeWire, WirePlumber, and `xdg-desktop-portal` are already part of this install. Screen capture stays on `xdg-desktop-portal-wlr`. See `docs/decisions/0036-gstreamer-desktop.md`.

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

When the archive publishes `hyprland-backgrounds`, the same command installs it, then replaces `wall0.png`, `wall1.png`, and `wall2.png` with the Corebrum images in `config/hypr/wallpapers`. It also installs `wall3.png`. Login and lock use `wall2.png`, so they show that Corebrum image. Ubuntu 24.04 has no `hyprland-backgrounds` package; the same four files are still copied to `/usr/share/hypr`. A package upgrade cannot put the upstream images back, because those paths are diverted. See `docs/decisions/0024-corebrum-wallpapers.md`. The same install copies `config/brand/logo.png` to `/usr/share/corebrum/logo.png` for the login and lock screens. See `docs/decisions/0037-login-lock-logo.md`.

## After a successful install

Reboot. The greeter is on VT 7 (`Ctrl+Alt+F7`). Log in with an existing user. Hyprland starts from `/usr/local/bin/corebrum-session` using `/etc/corebrum/hypr/hyprland.conf`. The first login opens a setup wizard: ROS 2, then RealSense, then AgenticROS, then the AI agents. RealSense and AgenticROS stay closed until ROS 2 is installed, because RealSense stops when the ROS apt source is missing. Each step accepts Install, Skip, or Exit. When ROS 2, RealSense, AgenticROS, and every AI agent are already installed, login writes `${XDG_STATE_HOME:-~/.local/state}/corebrum/setup-done` and does not open the wizard. Exit and a finished wizard write that same marker, and later logins do not open the wizard. `corebrum-setup again` opens it after that. Super+Space can still install each piece on its own. See `docs/decisions/0042-setup-wizard.md`. Super+Space lists Updates. Choosing Ubuntu runs `apt-get update` and `apt-get upgrade` on the current release. Corebrum fast-forwards this checkout and runs `sudo corebrum install desktop`. ROS 2 reruns `sudo corebrum install ros` and upgrades the `ros-<distro>-*` packages already installed, including the Zenoh router package. Zenoh reinstalls the pinned client in `/opt/corebrum/zenoh-cli` and, when `zenoh-fleet` is already on `PATH`, the pinned fleet package. AgenticROS restores `.mcp.json`, fast-forwards its checkout, rebuilds it, and runs `agenticros init --yes`. MCP setup rewrites that tracked file with this machine's ROS wrapper. AI Agents reruns the install command only for CLIs already on `PATH`. All runs those six steps in order and stops on the first failure. The terminal says when `/var/run/reboot-required` exists and does not reboot. A login reminder once a week asks the operator to open Updates and does not apply upgrades. See `docs/decisions/0045-software-updates.md`. When `start-hyprland` is installed, the session runs through that watchdog and still passes the Corebrum config. When the Ubuntu archive publishes `hyprland-qtutils`, the same install provides `hyprland-dialog`, which Hyprland uses for its dialogs. Ubuntu 24.04 does not publish that package. See `docs/decisions/0025-hyprland-startup.md`.

| Key | Action |
| --- | --- |
| Super+Return | Kitty |
| Super+Shift+Return | Firefox |
| Super+Shift+F | Files |
| Super+Shift+N | Text Editor |
| Super+W | Close the focused window |
| Super+F | Fullscreen |
| Super+T | Float or tile |
| Super+C | Copy |
| Super+X | Cut |
| Super+V | Paste |
| Super+Space | Fuzzel launcher. ROS 2 is listed there as `ROS 2   install` until `corebrum install ros` has been run, then as `ROS`. `Zenoh network` appears beside it only after that install |
| Super+Alt+Space | App grid |
| Super+S | Agent scratchpad terminal |
| Super+1 … Super+5 | Workspaces |
| Super+Shift+1 … Super+Shift+5 | Move the window to a workspace |
| Super+Shift+Arrows | Swap the focused tile with the one in that direction |
| Super+Shift+H J K L | Swap the focused tile: H left, J down, K up, L right |
| Super+Escape | Lock the screen with hyprlock |
| Super+Shift+Escape | Pause autolock, or resume it |
| Super+Shift+E | Log out and return to the greeter |
| Print | Copy a selected area |
| Super+P | Copy a selected area |
| Super+Shift+P | Copy the whole screen |
| Super+Print | Record a selected area to `~/Videos` |
| Super+Shift+Print | Stop the recording |
| Super+Alt+P | Record a selected area to `~/Videos` |
| Super+Alt+Shift+P | Stop the recording |
| Super+Shift+C | Clipboard history |
| Ctrl+Alt+F1 | Text console |

Super+C copies, Super+X cuts, and Super+V pastes in the focused window. A terminal receives Ctrl+Shift instead of Ctrl, so Ctrl+C there still interrupts the program. Clipboard history is Super+Shift+C, and Super+T floats or tiles the window. See `docs/decisions/0028-copy-paste-keys.md`.

`corebrum install desktop` installs the recorder and the camera preview as executable files. Running that install again marks an older copy executable when its contents are already current. Super+Print and Super+Alt+P record the selected area to `~/Videos`. The list offers Screen, Screen and audio when a microphone is present, Screen and webcam when a camera other than RealSense is present, and Screen and RealSense when `pyrealsense2` is installed. Audio and camera can be chosen together. Audio uses the default microphone. Webcam and RealSense video sit in the bottom-right of the selection. Choosing RealSense uses that camera, so a demo that needs it should choose Screen, audio, or the webcam. With none of those devices, the shortcut records the screen immediately. See `docs/decisions/0040-record-camera.md`.

Super+Space includes Keybindings. That entry lists the Super shortcuts in the table above. Choosing a row closes the list and does not run the shortcut.

Super+Space also lists Autolock. The screen locks after 10 minutes idle unless that menu, or Super+Shift+Escape, turns on Stay awake. The other rows are 5 minutes, 30 minutes, and 1 hour. Stay awake lasts until it is turned off or the session ends. Ubuntu 24.04 has no `hypridle` package, so that release keeps Super+Escape as the only lock. See `docs/decisions/0022-autolock.md`.

Super+Space lists Power. The rows are Log out, Reboot, and Power off. Choosing a row asks for that action again, and Cancel leaves the session running. Log out is the same exit as Super+Shift+E: Hyprland exits and the greeter returns. Reboot runs `systemctl reboot`. Power off runs `systemctl poweroff`. Typing reboot, shutdown, or log out finds Power and opens that list. See `docs/decisions/0044-power-menu.md`.

Waybar is the top bar: workspaces, window title, CPU, memory, network, and clock. Volume, mute, microphone mute, and brightness keys change the level and show a notification at the top right. Other applications use the same Mako popups. Hyprland's splash quotes are turned off. A transparent bar on the wallpaper reads `Corebrum: The Physical AI Operating System`. The grid starts with Terminal, Files, and Browser. Add a robotics tool later by appending `Label|command` to `/etc/corebrum/dashboard/tiles.conf`. Do not put `|` or `#` in the command.

```bash
./scripts/validate/desktop.sh
```

That script checks packages, config files, that greetd is enabled, and that `Hyprland --verify-config` accepts `/etc/corebrum/hypr/hyprland.conf`. It does not prove the session tiled a window. After you log in, confirm Super+Return, two windows tiling, Super+1 and Super+2, Super+F, and that Waybar shows the clock. Then switch to VT 1 and back.

Firefox is Ubuntu's transitional snap package. Installing the desktop profile installs that snap. Super+Space shows that Firefox row with the Firefox logo.

Super+Space lists Text Editor from the `gnome-text-editor` package installed with this profile. Choosing it opens a window for a new document. Typing `notepad` finds that row. Super+Shift+N opens it directly. See `docs/decisions/0039-text-editor.md`.

Super+Space lists Chromium separately. The entry says `install` until Canonical's `chromium` snap is present, and choosing it installs that snap. Ubuntu does not publish a Chrome or Chromium deb; `chromium-browser` is the transitional package, and the browser itself is the snap. After it is installed, the same entry launches `/snap/bin/chromium` and shows the Chromium logo. The snap's own `Chromium Web Browser` desktop files stay out of this menu.

Super+Space lists Wallpaper. Choosing it lists the Corebrum wallpapers in `/usr/share/hypr` and images in `~/Pictures` and `~/Pictures/Wallpapers`. The chosen image is saved under the user's state directory and drawn by `hyprpaper` on later logins. The desktop profile installs `hyprpaper`: the Ubuntu package on 26.04, and the pinned Hyprland PPA package on 24.04. See `docs/decisions/0043-hyprpaper-desktop.md`.

Super+Space lists Remote desktop. The entry says `install` until `wayvnc` is installed. Choosing it installs the Ubuntu package when this archive has one. Ubuntu 24.04 publishes `wayvnc` 0.7.2 and Ubuntu 26.04 publishes 0.9.1. After that, Start shares the logged-in desktop on port 5900 and opens the connection steps, including the password. A Mac uses Finder's Connect to Server with the `vnc://` address. Screen Sharing can use the same address without that prefix. It asks for the password and does not ask for a name. The picture uses the 24-bit color Screen Sharing can draw, so the Mac window shows the desktop. The Command key acts as Super, and Command+V pastes inside the shared desktop. Screen Sharing leaves its clipboard commands gray on this connection, so text copied in another Mac app is not sent. Windows uses TigerVNC Viewer with the address and `::5900`. One colon is a display number in TigerVNC, so the address is typed with both colons. The Remote Desktop app on Windows does not open this session. Linux uses Remmina with protocol VNC, the address and `:5900`, and an empty username. TigerVNC on Linux uses the Windows addresses. Those viewers keep Alt as Alt. Stop ends it. The server does not start at login, and the desktop profile does not install `wayvnc`. See `docs/decisions/0027-vnc-menu.md`.

Super+Space also lists AI Agents. Each CLI says `install` until its command is present. Choosing it installs that CLI, or launches it in a terminal when it is already installed. Typing the CLI name, such as `grok`, at the Super+Space prompt finds that CLI. The idle menu still shows AI Agents, and that submenu still lists the CLIs. The list is Antigravity CLI, Claude Code CLI, Codex CLI, Cursor CLI, Grok CLI, Hermes CLI, and OpenClaw. Gemini CLI is not listed: since June 18, 2026 it no longer signs in Gemini Code Assist for individuals, and Antigravity CLI is the replacement. The desktop profile does not install them. See `docs/decisions/0016-agent-menu.md`.

Super+Space lists Ollama. The entry says `install` until the `ollama` command is present. Choosing it installs Ubuntu `zstd` when that command is missing, then runs the official installer from `https://ollama.com/install.sh`. After that, the same entry lists local models and runs the chosen one with `ollama run`. The desktop profile does not install Ollama. See `docs/decisions/0032-ollama-menu.md`.

Super+Space lists Zenoh fleet. The entry says `install` until `zenoh-fleet` is present. Choosing it installs `@agenticros/zenoh-fleet` 0.1.4 with the desktop Node.js, then runs the wizard in the home directory. The default files land in `~/local-fleet/`. The wizard does not change the running Zenoh router, and the desktop profile does not install the package. See `docs/decisions/0033-zenoh-fleet-menu.md`.

Super+Space lists AgenticROS after ROS 2 is installed. The entry says `install` until `agenticros init` has written `~/.agenticros/config.json`. Choosing it installs `build-essential` and `python3` when they are missing. It uses the AgenticROS checkout next to this one, and clones `https://github.com/agenticros/agenticros.git` when that directory is missing. It then compiles `rclnodejs` against the installed ROS distro, regenerates its messages for that distro, installs the `node-datachannel` prebuild that `agenticros connect` needs for ARC, and runs `agenticros init --yes`, which puts the CLI on the Zenoh RMW and registers every agent already installed. Installing an agent later writes that same registration into the agent. The top bar shows AgenticROS status and can connect or disconnect AgenticROS Cloud. The desktop profile does not install AgenticROS. After it is installed, typing an action such as `Motors: Start` at the Super+Space prompt runs that action. The idle menu still shows AgenticROS. See `docs/decisions/0026-agenticros-menu.md`, `docs/decisions/0030-menu-search-submenus.md`, and `docs/decisions/0041-agenticros-clone.md`.

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

A broken Hyprland config sends you back to the greeter, because greetd starts it again when the session exits. On Ubuntu 26.04 that greeter is gtkgreet. On Ubuntu 24.04 it is agreety. Edit `/etc/corebrum/hypr/hyprland.conf` from VT 1. The previous greetd config, if the installer replaced one, is under `/var/log/corebrum/backups/`.

## Removal

```bash
sudo ./scripts/uninstall.sh --profile desktop
```

This disables greetd, restores the previous default target when this installer changed it, restores the previous greetd config from the backup it recorded, deletes Corebrum files under `/etc/corebrum` and `/usr/local/bin`, and removes the Hyprland PPA source, pin, and key. When `/usr/local/nvm/.corebrum-managed` is present it also removes that nvm checkout and the Node.js block in `/etc/bash.bashrc`. It does not remove Hyprland, libinput, Waybar, Firefox, or other packages. Reboot afterward.

`./scripts/uninstall.sh --profile base` still refuses to remove the base packages.

## What is not done

The operator continued to Phase 3 after this machine booted to Hyprland and showed Waybar. Confirm the key table above on the session if that has not been done. Workstation services are documented in `docs/installation/services.md`. Quickshell, ROS 2, Zenoh, RViz, Gazebo, RealSense, and Corebrum Mesh are not part of this install. AgenticROS is not installed by the desktop profile. Super+Space offers it after `corebrum install ros`.
