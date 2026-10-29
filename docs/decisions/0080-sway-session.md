# 0080. Sway session

Date: 2026-10-28
Status: Accepted

## Context

The desktop session was Hyprland. Ubuntu 24.04 has no `hyprland` package in the archive. The noble build in `ppa:cppiber/hyprland` replaces Wayland libraries, and this branch does not use it. Ubuntu 24.04 and 26.04 both publish Sway. On this resolute workstation the archive candidates are Sway 1.11-3, swaybg 1.2.1-1build1, swaylock 1.8.4-1, swayidle 1.9.0-1, and wlgreet 0.5.0-4. Noble's Sway is 1.9. The config has to be syntax Sway 1.9 accepts. Sway 1.9 has no rounded corners and no window animations.

Decision 0005 left wlgreet unused because it depends on Sway. With Sway installed, wlgreet runs in a minimal Sway. See `docs/decisions/0081-wlgreet-sway-greeter.md`. swaylock can draw `wall2.png` and a teal indicator. It cannot place `logo.png` the way hyprlock did, and it has no password field. Decision 0082 locks with gtklock.

Preflight still requires Ubuntu resolute. Installing this session on Ubuntu 24.04, and on a Jetson, is a later decision after the look is accepted. ROS 2 stays Lyrical.

## Decision

- The desktop profile installs `sway` from the Ubuntu archive. It also installs `swaybg`, `swayidle`, `wlgreet`, and `gtklock` when those candidates exist. It does not install `swaylock`, `hyprland`, `hyprpaper`, `hyprlock`, `hypridle`, `hyprland-qtutils`, or `cage`, and it does not add the Hyprland PPA. Packages already installed from that PPA stay on the machine. See `docs/decisions/0082-gtklock-password.md`.
- `/usr/local/bin/corebrum-session` runs `sway --config /etc/corebrum/sway/config` and sets `XDG_CURRENT_DESKTOP=sway`. Sway reads `WLR_DRM_DEVICES`, which the existing Pi helper already exports.
- New tiled windows split the longer side of the focused tile through `/usr/local/bin/corebrum-autotile`. A wide tile opens the next window beside it. A tall tile opens the next one below it. The helper line-buffers Sway's window events, because a pipe would hold them until the buffer filled and the split would stay horizontal. Gaps are 4 px inner and 8 px outer. The focused border is `#3d9a8b`. Super+S shows the agent terminal from the Sway scratchpad.
- The session draws `/usr/share/hypr/wall2.png` on every output. The wallpaper menu writes one path to `${XDG_STATE_HOME:-~/.local/state}/corebrum/wallpaper.path` and restarts `swaybg -m fill` over that image. Images stay under `/usr/share/hypr`. Login and lock stay on the same file.
- Super+Escape runs `gtklock` with that wallpaper and a password field. Login and lock draw the Corebrum logo above the prompt. See `docs/decisions/0082-gtklock-password.md` and `docs/decisions/0083-login-lock-logo.md`.
- Autolock starts `swayidle`. The default is 10 minutes. Stay awake is a systemd idle inhibitor for the rest of the session. swayidle honors that inhibitor. Choosing a timer restarts `swayidle` and leaves that inhibitor running. The list opens again so the `on` mark follows the saved timer and Stay awake. Escape closes the list.
- When `wlgreet` has a candidate, greetd runs a minimal Sway and `/usr/sbin/wlgreet`. The session command is `/usr/local/bin/corebrum-session`. If `wlgreet` is missing, greetd stays on agreety. VT 7 stays the greeter. VT 1 stays a text console. See `docs/decisions/0081-wlgreet-sway-greeter.md`.
- Waybar uses `sway/workspaces` and `sway/window`. Workspaces 1 through 5 stay on the top left, including when they are empty. The focused number is teal. Screen capture stays on `xdg-desktop-portal-wlr`. The same portal file is installed as `sway-portals.conf`, because the portal selects that name from `XDG_CURRENT_DESKTOP`.

## Consequences

A desktop install from this branch starts Sway on the next login. The session is stricter than the Hyprland session: no window animations and no rounded corners. Decision 0083 draws the logo on login and lock. `corebrum doctor` still passes on a machine whose installed session is the previous Hyprland config, and it tells the operator to run `sudo corebrum install desktop`. A broken Sway config returns to the greeter. Ctrl+Alt+F1 is the text console.
