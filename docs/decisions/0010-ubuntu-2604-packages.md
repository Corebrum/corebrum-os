# 0010. Ubuntu 26.04 uses archive Hyprland and ROS 2 Lyrical

Date: 2026-10-22
Status: Accepted

## Context

Corebrum OS was built for Ubuntu Server 24.04. Hyprland was not in that archive, so decision 0006 adds the pinned `ppa:cppiber/hyprland` only when `apt-cache policy` shows no Ubuntu archive build. On 2026-10-22 Ubuntu 26.04 (Resolute) publishes `hyprland` 0.53.3+ds-4 in universe. Quickshell is still absent from 26.04; it appears in Ubuntu 26.10, which this installer does not support. The session stays on Waybar, Fuzzel, and the Corebrum app grid on both releases.

ROS 2 Jazzy is the Tier 1 distribution for Ubuntu 24.04. ROS 2 Lyrical Luth, codename `lyrical`, is the LTS distribution whose Tier 1 Ubuntu platform is 26.04. The Resolute index on packages.ros.org has `ros-lyrical-ros-base`, `ros-lyrical-rmw-zenoh-cpp`, and `ros-lyrical-rmw-fastrtps-cpp`. The bootstrap package is `ros2-apt-source` 1.3.0 for resolute, sha256 `e70bc980395f4a3b366b9c5e7f8f9b4d63a4064fb115f6ff3bc52f7faa02ef69`. It carries the same Open Robotics key as the noble package, fingerprint `C1CF6E31E6BADE8868B172B4F42ED6FBAB17C654`. Lyrical's `desktop` and `rviz2` packages exist and stay out of this profile.

The Hyprland session file was checked on 0.56 from the 24.04 PPA. It does not set `dwindle:pseudotile`, the option removed in 0.55, so the same file is what 26.04's 0.53 package receives. That package has not been started on a 26.04 machine from this tree.

## Decision

- Preflight reads `VERSION_CODENAME` and accepts `noble` and `resolute`, x86-64 only. It does not match `VERSION_ID`. Jammy is Ubuntu 22.04 and is rejected. Other releases still stop.
- `noble` keeps the pinned Hyprland PPA when the archive has no `hyprland`. `resolute` never adds that PPA. If `resolute` has no archive `hyprland`, the desktop install stops.
- The ros profile selects Jazzy and the pinned noble `ros2-apt-source` deb on `noble`. It selects Lyrical Luth and the pinned resolute deb on `resolute`. Package lists are `manifests/packages/ros.txt` and `manifests/packages/ros-lyrical.txt`. The installer records the ROS codename in `/etc/corebrum/ros/distro`.
- An already installed `ros2-apt-source` is kept only when its version matches the running Ubuntu codename and the key fingerprint still matches.
- This decision does not upgrade a running 24.04 machine.

## Consequences

A 24.04 install behaves as it does today: Hyprland comes from the pinned PPA, and ROS 2 is Jazzy. A 26.04 install uses the Ubuntu `hyprland` package and ROS 2 Lyrical. Quickshell is still not installed. RViz, Gazebo, and RealSense stay out of both package lists. The 26.04 desktop has not been booted, so Hyprland 0.53 still needs a session check on that release before the desktop profile is called accepted there.
