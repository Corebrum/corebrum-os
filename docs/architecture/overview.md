# Architecture

Corebrum OS is a set of packages, configuration, and services installed onto Ubuntu Server 24.04 LTS x86-64. Ubuntu remains the operating system. APT remains the package manager. Corebrum does not build a kernel, an installer ISO, or a pacman-based distribution.

```text
Ubuntu Server 24.04
  Corebrum base profile          Phase 1
  Hyprland + Quickshell session  later, after Quickshell is verified on Ubuntu
  ROS 2 Jazzy + Zenoh RMW        later
  RViz, Gazebo, RealSense        later
  AgenticROS, Corebrum Mesh      later
```

The session follows [Omarchy](https://github.com/omacom/omarchy). Hyprland tiles windows, with dwindle as the default layout. Quickshell provides the menu, top bar, dock, and app grid. A robotics tool is a grid tile that opens into a workspace. The decision is recorded in `docs/decisions/0002-omarchy-shell-on-ubuntu.md`.

Phase 1 installs the base profile only. It does not change Netplan, NetworkManager, the bootloader, or user dotfiles.
