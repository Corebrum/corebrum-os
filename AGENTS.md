# AGENTS.md

Instructions for coding agents working on Corebrum OS.

Corebrum OS is an open-source Ubuntu Server 24.04 and 26.04 environment for Physical AI. It is inspired by [Omarchy](https://github.com/omacom/omarchy) (Hyprland tiling, Quickshell menu, and app grid) and implemented with APT, not Arch or pacman. Read `COREBRUM_BUILD_PLAN.md` and `docs/decisions/` before changing the system.

## Engineering rules

1. Work on one development phase at a time. Do not start the next phase until the current phase passes its acceptance criteria.
2. Never assume that an external package, CLI, API, or GitHub repository exists without verifying it.
3. Inspect the existing repository before creating or changing files.
4. Prefer official Ubuntu and ROS 2 packages when available.
5. Use idempotent installation scripts that can safely be run multiple times.
6. Never overwrite existing user configuration without a backup or explicit permission.
7. Separate configuration, package installation, service management, and validation.
8. Do not execute destructive disk, network, or bootloader operations automatically.
9. Pin compatible robotics dependencies and document version constraints in `manifests/versions/`.
10. Run tests and document their results before marking a phase complete.
11. Record implementation decisions and deviations in `docs/decisions/`.
12. Never hardcode credentials, API keys, or secrets.
13. Support clean installation, upgrade, and removal wherever practical.
14. Prefer maintainable integrations over forks of upstream projects. Do not vendor Omarchy.
15. Do not claim success only because an installer exited successfully. Validate runtime behavior.

## Workflow

Plan, implement, test, document, review, then commit.

The root installer (`scripts/install.sh`) orchestrates phase scripts. It must support `--dry-run` before any system change. CI may run lint, unit tests, and `--dry-run` only. CI must not install Corebrum profiles onto the runner.

## Current boundary

Phase 5 is in progress: ROS 2 and `rmw_zenoh_cpp`. The operator continued after Phase 4 installed the `corebrum` command. `corebrum install ros` installs the base profile, the Zenoh router, and the Zenoh client CLI in `/opt/corebrum/zenoh-cli`. The `zenoh` command connects to that router. It does not install `zenohd`. After that install, Super+Space lists `Zenoh network`, which runs `zenoh network`. See `docs/decisions/0023-zenoh-cli.md`. It does not install the desktop. The command does not write `~/.config`. The installer reads `VERSION_CODENAME`: noble selects Jazzy, and resolute selects Lyrical Luth. Jammy is not supported. See `docs/decisions/0009-ros-jazzy-zenoh.md` and `docs/decisions/0010-ubuntu-2604-packages.md`.

The desktop session is Hyprland dwindle tiling, Waybar, Fuzzel, and a Corebrum app grid, plus a scratchpad for an agent terminal. Super+Space can install and launch Ubuntu's Chromium snap. Super+Space lists Wallpaper. Choosing it installs Ubuntu `hyprpaper` when that package is in the archive, then shows a list of images. The desktop profile does not preinstall `hyprpaper`, because Ubuntu 24.04 has no `hyprpaper` package. Super+Space lists Remote desktop. Choosing it installs Ubuntu `wayvnc` when that package is in the archive. Start listens on port 5900 and shows the `vnc://` address plus the password macOS Screen Sharing asks for. Screen Sharing does not ask for a name. The Command key acts as Super. The server does not start at login, and the desktop profile does not preinstall `wayvnc`. See `docs/decisions/0027-vnc-menu.md`. The chosen image is stored under the user's state directory. The install copies Corebrum `wall0.png` through `wall3.png` to `/usr/share/hypr`, which is also what login and lock use. See `docs/decisions/0020-hyprpaper-menu.md` and `docs/decisions/0024-corebrum-wallpapers.md`. Volume and brightness keys show a Mako notification. The desktop profile installs `libnotify-bin` so applications can call `notify-send`. See `docs/decisions/0021-notifications.md`. The screen locks after 10 minutes idle. Super+Space Autolock changes that timer, and Stay awake or Super+Shift+Escape pauses it for the session. Ubuntu 24.04 has no `hypridle` package, so that release still locks only with Super+Escape. See `docs/decisions/0022-autolock.md`. Firefox stays in the desktop package list. Ubuntu 26.04 logs in through gtkgreet inside cage and locks with hyprlock on Super+Escape. Ubuntu 24.04 has neither package, so that release keeps the agreety greeter. See `docs/decisions/0015-hyprlock-gtkgreet.md`. Super+Space lists AI Agents. Each CLI installs on selection or launches when it is already present. The desktop profile does not preinstall them. See `docs/decisions/0016-agent-menu.md`. Quickshell is not in the Ubuntu 24.04 or 26.04 archive. Hyprland is installed from `ppa:cppiber/hyprland` on noble when the Ubuntu archive has no `hyprland` package. That archive is pinned so only Hyprland and the libraries it requires come from it. resolute uses the archive `hyprland` package and does not add the PPA. The session starts through `start-hyprland` when that helper is installed, and still loads `/etc/corebrum/hypr/hyprland.conf`. The desktop profile installs Ubuntu `hyprland-qtutils` when the archive has it, because Hyprland looks for `hyprland-dialog`. Ubuntu 24.04 does not publish that package, and it is not taken from the Hyprland PPA. See `docs/decisions/0006-hyprland-ppa.md`, `docs/decisions/0010-ubuntu-2604-packages.md`, and `docs/decisions/0025-hyprland-startup.md`. The desktop profile installs Node.js 26.x, npm, and pnpm with nvm under `/usr/local/nvm`. It does not write `~/.nvm` or `~/.bashrc`. See `docs/decisions/0012-node-nvm.md`. Do not add any third-party repository other than that pinned PPA and, for the ros profile, the official ROS 2 apt repository. Do not upgrade a running machine to 26.04 from the installer.

Phase 3 installs NetworkManager, Bluetooth, PipeWire, and the related Ubuntu tools as part of `--profile desktop`. It does not edit existing Netplan files and it does not switch the Ethernet renderer. Wi-Fi is managed by NetworkManager. Ethernet stays on the existing Netplan renderer. See `docs/decisions/0007-workstation-services.md`.

Super+Space lists AgenticROS after ROS 2 is installed. Choosing it builds the clone beside this checkout, runs `agenticros init --yes`, and forces `RMW_IMPLEMENTATION=rmw_zenoh_cpp` for the CLI and for every agent's MCP server. Installing an agent before or after AgenticROS writes that agent's config so the agent uses AgenticROS for ROS on this machine. The desktop profile does not preinstall AgenticROS. See `docs/decisions/0026-agenticros-menu.md`. Corebrum Mesh stays uninstalled until a later phase is explicitly approved. RViz, Gazebo, Nav2, MoveIt, and RealSense are not part of `corebrum install ros`. Super+Space lists ROS 2 with an install indicator, and the ROS submenu installs or launches RViz, Gazebo, Nav2, and MoveIt. RealSense is its own Super+Space entry. Choosing it installs librealsense, realsense-ros, and pyrealsense2. After that, the same entry opens a submenu: RealSense Viewer launches `realsense-viewer`, and RealSense ROS opens a terminal running `ros2 launch realsense2_camera rs_launch.py`. See `docs/decisions/0011-ros-launcher-menu.md` and `docs/decisions/0013-realsense-menu.md`.
