# 0009. ROS 2 Jazzy and one Zenoh router

Date: 2026-10-22
Status: Accepted

## Context

Phase 5 needs ROS 2 Jazzy, the Zenoh RMW, a router, developer tools, and a DDS fallback. Jazzy's Ubuntu target is Noble. The packages are not in the Ubuntu archive. The current official bootstrap is the `ros2-apt-source` package, which installs the Open Robotics key and a source entry for `http://packages.ros.org/ros2/ubuntu`. On 2026-10-22 the noble package is `ros2-apt-source` 1.3.0, published as `ros2-apt-source_1.3.0.noble_all.deb` with sha256 `f31d84adf5054c7d60ded0e82c0f776a77ea33af53d08f40b9ad7c94cca55296`. The key fingerprint in that package is `C1CF6E31E6BADE8868B172B4F42ED6FBAB17C654`, uid "Open Robotics <info@osrfoundation.org>".

The noble index on that date had `ros-jazzy-ros-base` 0.11.0, `ros-jazzy-rmw-zenoh-cpp` 0.2.11, and `ros-jazzy-rmw-fastrtps-cpp` 8.4.4. `ros-jazzy-desktop` and `ros-jazzy-rviz2` exist and are left for a later phase. `rmw_zenoh_cpp` does not discover peers without a router: multicast scouting is off, and sessions connect to `tcp/localhost:7447`. The packaged router listens on `tcp/[::]:7447`. There is one router binary, `rmw_zenohd`, and no systemd unit in the package.

Official ROS install instructions also run `apt upgrade`. This machine already has the Hyprland PPA's libinput and libxkbcommon. A full upgrade is outside this phase.

## Decision

- `corebrum install ros` installs the base profile, then ROS 2. It does not install the desktop profile.
- The installer downloads the pinned 1.3.0 noble `ros2-apt-source` deb, checks the sha256, checks the key fingerprint, and installs it. If that package is already installed, it keeps it when the fingerprint still matches. It does not follow GitHub "latest".
- It does not edit `/etc/apt/sources.list.d/ubuntu.sources`. It stops if `noble-updates` or `universe` is missing. It does not run `apt upgrade`.
- The package set is `ros-jazzy-ros-base`, `ros-jazzy-rmw-zenoh-cpp`, `ros-jazzy-rmw-fastrtps-cpp`, `ros-jazzy-demo-nodes-cpp`, `ros-jazzy-action-tutorials-cpp`, and `ros-dev-tools`. Jazzy deb versions are recorded, not frozen with apt pins.
- The default RMW is `rmw_zenoh_cpp`, stored in `/etc/corebrum/ros/rmw`. `corebrum ros rmw fastrtps` selects `rmw_fastrtps_cpp` for new login shells. Neither choice writes `~/.bashrc` or `~/.config`.
- `ROS_DOMAIN_ID` defaults to 0. A ROS namespace is the node namespace, not a second router.
- One systemd service, `corebrum-zenoh-router.service`, runs `rmw_zenohd` with the package's default router config. `Restart=on-failure` and `RestartSec=2`. The installer refuses to start it when another `rmw_zenohd` is already running.
- The router listens on TCP port 7447 on all interfaces and has no authentication in this phase. Local sessions keep the upstream default and connect to `tcp/localhost:7447`.
- A real install starts a talker and listener, calls `add_two_ints`, sends a Fibonacci action goal, restarts the router, and checks `/chatter` again. Those nodes use `ROS_DOMAIN_ID=42` so they stay off the default domain.
- `rosdep init` runs once. `rosdep update` is left to the user. The installer does not write the user home.
- Uninstall disables the router and removes Corebrum's unit and ROS files. It leaves the ROS apt packages and `ros2-apt-source` installed.

## Consequences

A second machine is not part of `make check`. It connects its Zenoh sessions to `tcp/<this-host>:7447`, as documented in `docs/installation/ros.md`. Login shells and `corebrum-terminal` source `/etc/profile.d/corebrum-ros.sh`. Kitty itself is not a login shell, so the terminal launcher has to source that file or `ros2` is missing from a new window. The Hyprland session sources it on the next login. RViz, Gazebo, and RealSense stay out of this profile.
