# Architecture

Corebrum OS is a set of packages, configuration, and services installed onto Ubuntu Server 24.04 LTS x86-64. Ubuntu remains the operating system. APT remains the package manager. Corebrum does not build a kernel, an installer ISO, or a pacman-based distribution.

```text
Ubuntu Server 24.04
  Corebrum base profile                         Phase 1
  Hyprland + Waybar + Fuzzel + app grid         Phase 2, Hyprland from ppa:cppiber/hyprland
  ROS 2 Jazzy + Zenoh RMW                       later
  RViz, Gazebo, RealSense                       later
  AgenticROS, Corebrum Mesh                     later
```

The session follows [Omarchy](https://github.com/omacom/omarchy). Hyprland tiles windows, with dwindle as the default layout. Quickshell was the preferred shell. It is not in the Ubuntu 24.04 archive, so Waybar, Fuzzel, and the Corebrum app grid are the session. A robotics tool is a grid tile that opens into a workspace. The decisions are `docs/decisions/0002-omarchy-shell-on-ubuntu.md` and `docs/decisions/0005-desktop-packages-on-noble.md`.

Phase 2 configuration lives under `/etc/corebrum` and is passed on the command line. The installer does not write `~/.config`, and it does not change Netplan, NetworkManager, or the bootloader. greetd, when the desktop profile is actually applied, owns VT 7. VT 1 stays a text console.
