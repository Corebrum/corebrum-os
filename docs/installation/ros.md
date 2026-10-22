# ROS 2 and Zenoh

Phase 5 installs one ROS 2 release and one Zenoh router. Ubuntu noble gets Jazzy. Ubuntu resolute gets Lyrical Luth. The decisions are `docs/decisions/0009-ros-jazzy-zenoh.md` and `docs/decisions/0010-ubuntu-2604-packages.md`. This profile does not install the Hyprland desktop, RViz, Gazebo, or RealSense.

Preview:

```bash
./scripts/corebrum.sh install ros --dry-run
```

Apply:

```bash
sudo ./scripts/corebrum.sh install ros
```

That also installs the base profile when it is missing. It adds the official ROS 2 apt repository, installs `ros-base` and `rmw_zenoh_cpp` for the release that matches this Ubuntu version, and starts `corebrum-zenoh-router.service`. It does not edit existing Netplan files and it does not run `apt upgrade`. The chosen codename is written to `/etc/corebrum/ros/distro`.

A new Super+Return terminal sources `/etc/profile.d/corebrum-ros.sh` before Kitty starts. The terminal you already have does not change. Close it and open another. A shell that was not started by Corebrum can still run:

```bash
source /etc/profile.d/corebrum-ros.sh
```

| Command | Effect |
| --- | --- |
| `corebrum ros status` | Distro, selected RMW, router state |
| `corebrum ros topics` | `ros2 topic list` with the selected RMW |
| `corebrum ros rmw zenoh` | New shells use `rmw_zenoh_cpp` |
| `corebrum ros rmw fastrtps` | New shells use Fast DDS instead |
| `corebrum zenoh status` | Router unit, process count, listen address |
| `corebrum zenoh peers` | Router address and this machine's IPv4 addresses |

`corebrum ros rmw` needs root. It writes `/etc/corebrum/ros/rmw` and leaves the router running.

## Conventions

- `ROS_DISTRO` is `jazzy` on Ubuntu noble and `lyrical` on Ubuntu resolute.
- `ROS_DOMAIN_ID` defaults to 0. Nodes on another domain do not discover each other, even through the same router.
- A robot prefix is a ROS namespace, for example `__ns:=/robot1`.
- Local sessions connect to `tcp/localhost:7447`. The router listens on `tcp/[::]:7447` with multicast scouting disabled. That is the upstream `rmw_zenoh` default. Port 7447 is open on the machine's interfaces and the router does not authenticate clients.
- There is one router. Do not also run `ros2 run rmw_zenoh_cpp rmw_zenohd`.

## Router restart

The unit uses `Restart=on-failure` and waits 2 seconds before trying again. A crash of `rmw_zenohd` brings the router back. Clients drop in-flight messages and discover each other again after they reconnect to `tcp/localhost:7447`.

Restart it on purpose with:

```bash
sudo systemctl restart corebrum-zenoh-router.service
```

If it stays failed because port 7447 is already taken, another router is running. Stop that process and then:

```bash
sudo systemctl reset-failed corebrum-zenoh-router.service
sudo systemctl start corebrum-zenoh-router.service
```

The install checks this once: it exchanges a topic, a service, and an action on `ROS_DOMAIN_ID` 42, restarts the router, and checks the topic again. Repeat that with:

```bash
sudo ./scripts/validate/ros-graph.sh
```

## A second machine

`make check` does not cover a second computer. On the other Ubuntu 24.04 machine, install this same profile, then point its sessions at this machine's router instead of only at localhost:

1. On this machine, run `corebrum zenoh peers` and choose an address.
2. On the other machine, copy `/opt/ros/<distro>/share/rmw_zenoh_cpp/config/DEFAULT_RMW_ZENOH_SESSION_CONFIG.json5` (`jazzy` or `lyrical`) and add `tcp/<this-address>:7447` to the session connect endpoints.
3. Export `ZENOH_SESSION_CONFIG_URI` to that file, and `RMW_IMPLEMENTATION=rmw_zenoh_cpp`, in the shells that should join this router.
4. Leave both machines on `ROS_DOMAIN_ID` 0, or set both to the same other value.
5. Run a talker here and a listener there.

Do not start a second `rmw_zenohd` on the machine that is only connecting.

## DDS fallback

```bash
sudo corebrum ros rmw fastrtps
```

New login shells then use Fast DDS. The Zenoh router keeps running so `corebrum ros rmw zenoh` can switch back without installing packages again. Fast DDS still uses its own discovery. `ROS_LOCALHOST_ONLY` is a DDS setting; it does not select the RMW.

## Developer tools

`ros-dev-tools` provides colcon and rosdep. The installer runs `rosdep init` when `/etc/ros/rosdep/sources.list.d/20-default.list` is missing. Each user still runs:

```bash
rosdep update
```

## Removal

```bash
sudo corebrum uninstall ros
```

This disables the router and removes Corebrum's unit, profile script, and `/etc/corebrum/ros`. The ROS packages and the apt source stay installed. To remove the packages as well:

```bash
sudo apt remove '~nros-jazzy-*' ros-dev-tools ros2-apt-source
sudo apt autoremove
```

On Ubuntu 26.04 the package pattern is `~nros-lyrical-*` instead of `~nros-jazzy-*`.
