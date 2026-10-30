# ROS 2 and Zenoh

Phase 5 installs one ROS 2 release and one Zenoh router. Ubuntu 24.04 gets Jazzy. Ubuntu 26.04 gets Lyrical Luth. The decisions are `docs/decisions/0009-ros-jazzy-zenoh.md`, `docs/decisions/0010-ubuntu-2604-packages.md`, and `docs/decisions/0088-ubuntu-2404.md`. This profile does not install the desktop session, RViz, Gazebo, Nav2, MoveIt, or RealSense.

On a desktop install, Super+Space lists `ROS 2   install` before this profile is installed. The row icon is the ROS mark at `/usr/share/corebrum/ros.png`. See `docs/decisions/0066-ros-menu-icon.md`. Choosing it runs the command below in a terminal. After it finishes, Super+Space lists `ROS` and `Zenoh network`. `ROS` opens RViz, Gazebo, Nav2, and MoveIt. Typing `gazebo`, `rviz`, `nav2`, or `moveit` at the Super+Space prompt finds that tool. The idle menu still shows `ROS`, and that submenu still lists the tools. `Zenoh network` runs `zenoh network` and draws the nodes connected to the router. Zenoh network and Zenoh fleet use the Zenoh mark at `/usr/share/corebrum/zenoh.png`. See `docs/decisions/0068-zenoh-menu-icon.md`. That row is absent until ROS and the Zenoh CLI are installed. `Zenoh fleet` is a separate Super+Space entry. It installs `@corebrum/zenoh-fleet` 0.1.4 and runs the configuration wizard. The wizard writes files in the home directory and does not replace this router. See `docs/decisions/0033-zenoh-fleet-menu.md`. A tool that is not installed yet is marked `install` and choosing it installs that package. A tool that is installed launches. RealSense is a separate Super+Space entry. The row icon is the RealSense mark at `/usr/share/corebrum/realsense.png`. See `docs/decisions/0069-realsense-menu-icon.md`. It installs librealsense with `realsense-viewer`, the ROS camera packages, and `pyrealsense2` for the system Python. After that install, the entry opens a submenu: RealSense Viewer launches the viewer, and RealSense ROS opens a terminal running `ros2 launch realsense2_camera rs_launch.py`. Typing either name at the Super+Space prompt launches it. The idle menu still shows RealSense. See `docs/decisions/0011-ros-launcher-menu.md` and `docs/decisions/0013-realsense-menu.md`.

Preview:

```bash
./scripts/corebrum.sh install ros --dry-run
```

Apply:

```bash
sudo ./scripts/corebrum.sh install ros
```

That also installs the base profile when it is missing. It adds the official ROS 2 apt repository, installs `ros-base` and `rmw_zenoh_cpp` for the release that matches this Ubuntu version, and starts `corebrum-zenoh-router.service`. It installs the Zenoh client CLI into `/opt/corebrum/zenoh-cli` and links it as `zenoh`. Run the same command again on a machine that already has ROS. The install is idempotent, and its graph check restarts the router once. It does not edit existing Netplan files, it does not edit `/etc/apt/sources.list.d/ubuntu.sources`, and it does not run `apt upgrade`. The chosen codename is written to `/etc/corebrum/ros/distro`.

`universe` still has to be present already. When the `<codename>-updates` pocket is missing, as on the Ubuntu 26.04 Raspberry Pi image, the installer writes `/etc/apt/sources.list.d/corebrum-ubuntu-updates.sources` for that pocket and uses the same URI, components, and signing key as the release stanza. A machine that already lists the updates pocket does not gain that file. See `docs/decisions/0061-ubuntu-updates-pocket.md`.

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
| `zenoh info` | Client session against the existing router |
| `zenoh subscribe -k 'rt/**'` | Print samples published on a key expression |

`corebrum ros rmw` needs root. It writes `/etc/corebrum/ros/rmw` and leaves the router running.

## Conventions

- `ROS_DISTRO` is `jazzy` on Ubuntu 24.04 and `lyrical` on Ubuntu 26.04.
- `ROS_DOMAIN_ID` defaults to 0. Nodes on another domain do not discover each other, even through the same router.
- A robot prefix is a ROS namespace, for example `__ns:=/robot1`.
- Local sessions connect to `tcp/localhost:7447`. The router listens on `tcp/[::]:7447` with multicast scouting disabled. That is the upstream `rmw_zenoh` default. Port 7447 is open on the machine's interfaces and the router does not authenticate clients.
- There is one router. Do not also run `ros2 run rmw_zenoh_cpp rmw_zenohd`.
- `zenoh` is the client CLI. It lives in `/opt/corebrum/zenoh-cli` and does not install `zenohd`. A command with no session flags connects to `tcp/127.0.0.1:7447` with multicast scouting off. `--mode`, `--connect`, `--listen`, or `--config` uses the session you pass instead. See `docs/decisions/0023-zenoh-cli.md`.

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

`make check` does not cover a second computer. Install this same profile on the other machine. Each machine may keep its own router. The shells that exchange messages connect to one router as Zenoh clients.

1. On the machine whose router will carry the messages, run `corebrum zenoh peers` and choose an address.
2. On both machines, copy `/opt/ros/jazzy/share/rmw_zenoh_cpp/config/DEFAULT_RMW_ZENOH_SESSION_CONFIG.json5` or the same file under `/opt/ros/lyrical`, matching the installed release.
3. In that copy, set `mode` to `client` and set the connect endpoint to `tcp/<router-address>:7447`. Leave the listen endpoint on `tcp/localhost:0`.
4. Export `ZENOH_SESSION_CONFIG_URI` to that file, and `RMW_IMPLEMENTATION=rmw_zenoh_cpp`, in the talker shell and the listener shell.
5. Leave both machines on `ROS_DOMAIN_ID` 0, or set both to the same other value.
6. Run a talker on one machine and a listener on the other.

A publisher left on the default peer session listens on `127.0.0.1`. The other machine can see that session and cannot open it. On 2026-10-26 a client session on both sides carried `/corebrum_link` from 192.168.8.100 to 192.168.8.193. The clocks differed by about 11 seconds, so Zenoh replaced timestamps more than 500 ms off, and the message text still arrived. See `docs/decisions/0049-two-machine-zenoh.md`.

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

This disables the router and removes Corebrum's unit, profile script, `/etc/corebrum/ros`, the Zenoh client in `/opt/corebrum/zenoh-cli`, and `corebrum-ubuntu-updates.sources` when that file was added. The ROS packages and the ROS apt source stay installed. `ubuntu.sources` stays as it was. To remove the packages as well:

```bash
sudo apt remove '~nros-jazzy-*' '~nros-lyrical-*' ros-dev-tools ros2-apt-source
sudo apt autoremove
```

That removes the Jazzy or Lyrical packages this profile installed. The other pattern matches nothing on a machine that has only one release.
