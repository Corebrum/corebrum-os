# Sway session and the Hyprland desktop

This note compares the desktop dependencies on `sway-session` with `master`. The session change is commit `0825832`. It is here so a later choice to keep Sway, in order to support Ubuntu 24.04 while NVIDIA drivers are still aimed at that release, starts from the package list rather than from the look of the desktop.

Both branches still refuse Ubuntu 24.04 in preflight. `scripts/lib/preflight.sh` accepts `VERSION_CODENAME=resolute` only, on `x86_64` and `aarch64`. See `docs/decisions/0063-ubuntu-2604-arm.md`. The Sway desktop removes the Hyprland personal archive. It does not, by itself, make a 24.04 install succeed.

## What the desktop profile installs

`master` names `hyprland` in `manifests/packages/desktop.txt` and then adds the pieces the archive has. `sway-session` names `sway` in that manifest and adds `wtype`. The rest of that file is shared: Waybar, Kitty, Fuzzel, wofi, greetd, Thunar, Firefox, GNOME Text Editor, Mako, espeak, the icon and cursor themes, `xdg-desktop-portal-wlr`, GStreamer, XWayland, and the GTK menu libraries.

| Role | `master` | `sway-session` |
| --- | --- | --- |
| Compositor | `hyprland` | `sway` |
| Wallpaper | `hyprpaper`, and `hyprland-backgrounds` when the archive has it | `swaybg`. Wallpapers are still copied to `/usr/share/hypr` |
| Idle timer | `hypridle`, and only when `hyprlock` is also installable | `swayidle` |
| Lock screen | `hyprlock` | `gtklock` |
| Login | `gtkgreet` inside `cage` | `wlgreet` inside a minimal Sway |
| Hyprland dialogs | `hyprland-qtutils` from the Ubuntu archive | omitted |
| Copy, cut, and paste | `hyprctl dispatch sendshortcut` | `wtype` |
| Screen capture | `xdg-desktop-portal-wlr`, file `hyprland-portals.conf` | the same portal, also installed as `sway-portals.conf` because the session sets `XDG_CURRENT_DESKTOP=sway` |
| Display device on a Pi | `AQ_DRM_DEVICES` for Hyprland's aquamarine | `WLR_DRM_DEVICES` for Sway. The helper still exports both |

`sway-session` does not install `swaylock`, `hyprland`, `hyprpaper`, `hyprlock`, `hypridle`, `hyprland-qtutils`, or `cage`. A package already on the machine from an earlier desktop install stays installed. See `docs/decisions/0080-sway-session.md` and `docs/decisions/0082-gtklock-password.md`.

Phase 2 on `master` calls `corebrum_install_hyprland_ppa`. Phase 2 on `sway-session` does not. `scripts/lib/ppa.sh` and `manifests/packages/hyprland-ppa.txt` are still in the tree. Desktop uninstall on `master` removes that source, pin, and key. See `docs/decisions/0006-hyprland-ppa.md`.

The Hyprland session files remain under `config/hypr/`. The Sway installer copies `config/sway/config`, the gtklock files, and `config/greetd/sway-config`. It does not copy `hyprland.conf`, `hyprlock.conf`, or `hypridle.conf`.

## Ubuntu 26.04, the release this branch runs on

On resolute the archive candidates recorded for this session are Sway 1.11-3, swaybg 1.2.1-1build1, swayidle 1.9.0-1, wlgreet 0.5.0-4, and gtklock 4.0.0-1build1. `wtype` is 0.4-3build1. gtklock 4.0.0 locks through `ext-session-lock` and `libgtk-session-lock0`. The same packages are published for amd64 and arm64. arm64 indexes are on `ports.ubuntu.com`. See `docs/decisions/0080-sway-session.md`, `docs/decisions/0082-gtklock-password.md`, and `docs/decisions/0072-ports-ubuntu-archive.md`.

`master` on the same release takes Hyprland 0.53.3+ds-4 from that archive and does not add the PPA. Hyprland 0.53 has window animations and 6 px rounded corners. Sway 1.11 has neither, and the Sway config does not turn any on. See `docs/decisions/0010-ubuntu-2604-packages.md`.

## Ubuntu 24.04, if this stack is kept for it

Noble publishes the Sway session packages. It does not publish `hyprland`. The Hyprland path on noble is `ppa:cppiber/hyprland`, which is amd64-only and replaces `libinput10` and `libxkbcommon0` with PPA builds. The pin list is `manifests/packages/hyprland-ppa.txt`: `hyprland`, `hyprland-data`, aquamarine, hyprcursor, hyprgraphics, hyprlang, hyprutils, hyprwire, `libdisplay-info3`, `libudis86.1`, `libxcb-errors1`, the libinput and libxkbcommon packages, plus `hyprpaper` and `libhyprtoolkit6`. Waybar, Fuzzel, and PipeWire stay on the Ubuntu archive. See `docs/decisions/0005-desktop-packages-on-noble.md`, `docs/decisions/0006-hyprland-ppa.md`, and `docs/decisions/0060-arm64-desktop.md`.

Sway on noble is 1.9. The config on this branch is written for that syntax. Sway 1.9 has no rounded corners and no window animations, which is also true of the 1.11 package on Ubuntu 26.04. Noble's other candidates, from the archive listings and from decision 0005, are:

| Package | Ubuntu 24.04 noble | Ubuntu 26.04 resolute, this session |
| --- | --- | --- |
| `sway` | 1.9 | 1.11-3 |
| `swaybg` | 1.2.0-2build2 | 1.2.1-1build1 |
| `swayidle` | 1.8.0-1 | 1.9.0-1 |
| `wlgreet` | 0.4.1 | 0.5.0-4 |
| `gtklock` | 2.1.0-1build2 | 4.0.0-1build1 |
| `wtype` | 0.4-3 | 0.4-3build1 |

Two of those version gaps matter before calling the lock screen and the greeter ready on noble.

`gtklock` 2.1.0 is the noble package. `--layout` and `ext-session-lock` arrived in gtklock 3.0.0. This branch's lock screen is gtklock 4.0.0: `config/gtklock/config.ini` sets `layout` and `style`, and the password field comes from `config/gtklock/layout.ui`. That file has not been run on gtklock 2.1.0.

`config/greetd/wlgreet.toml` is marked for wlgreet 0.5. Noble's recorded candidate is wlgreet 0.4.1, and that package depends on `sway`. The greeter on this branch is Sway plus `/usr/sbin/wlgreet`, because Ubuntu's `cage` has no layer-shell and wlgreet 0.5 exits when the compositor lacks it. See `docs/decisions/0081-wlgreet-sway-greeter.md`. The 0.4.1 config format still needs a check against that toml.

`wtype` 0.4 is in noble for amd64 and arm64. Super+C, Super+X, and Super+V on Sway go through it. See `docs/decisions/0086-sway-edit-keys.md`.

## What this branch leaves alone

ROS 2 stays Lyrical, from the official ROS repository, on resolute. Jazzy is the 24.04 ROS distribution, and this commit does not put it back. RealSense, AgenticROS, the AI agent CLIs, Node.js under `/usr/local/nvm`, NetworkManager, and PipeWire are unchanged. Accepting noble means changing preflight and the ROS selection as well as rechecking gtklock 2.1.0 and wlgreet 0.4.1. The compositor package itself is already in the Ubuntu 24.04 archive for amd64 and arm64.
