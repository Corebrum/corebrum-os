# Architecture

Corebrum OS is a set of packages, configuration, and services installed onto Ubuntu Server 24.04 or 26.04. x86-64 and ARM64 (aarch64) are both supported, including Raspberry Pi. Other Ubuntu releases are not a target. Ubuntu remains the operating system. APT remains the package manager. Corebrum does not build a kernel, an installer ISO, or a pacman-based distribution.

```text
Ubuntu Server 24.04 or 26.04 (x86-64 or ARM64)
  Corebrum base profile                         Phase 1
  Sway + Waybar + Fuzzel + app grid             Phase 2, Ubuntu archive
  NetworkManager, PipeWire, portals, disks     Phase 3, Ubuntu archive, Ethernet stays on Netplan
  corebrum install, status, doctor, config     Phase 4
  ROS 2 Jazzy or Lyrical + rmw_zenoh_cpp        Phase 5, official ROS apt repository
  RViz, Gazebo, RealSense                       Super+Space
  AgenticROS                                    Super+Space, not a profile
```

The session follows [Omarchy](https://github.com/omacom/omarchy). Hyprland tiles windows, with dwindle as the default layout. Quickshell was the preferred shell. It is not in the Ubuntu 26.04 archive, so Waybar, Fuzzel, and the Corebrum app grid are the session. A robotics tool is a grid tile that opens into a workspace. The decisions are `docs/decisions/0002-omarchy-shell-on-ubuntu.md`, `docs/decisions/0005-desktop-packages-on-noble.md`, and `docs/decisions/0063-ubuntu-2604-arm.md`.

Phase 2 configuration lives under `/etc/corebrum` and is passed on the command line. The installer does not write `~/.config` and it does not change the bootloader. Phase 3 installs NetworkManager beside the existing Netplan renderer and does not edit existing Netplan files. greetd, when the desktop profile is actually applied, owns VT 7. VT 1 stays a text console.
