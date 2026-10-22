# Corebrum OS

The operating environment for Physical AI. Corebrum OS runs on Ubuntu Server 24.04 or 26.04 LTS (x86-64). It is not a new kernel or a new package manager.

The desktop follows [Omarchy](https://github.com/omacom/omarchy): a keyboard-first Hyprland session and an app grid. Robotics tools such as ROS 2 (Zenoh RMW), RViz, and Gazebo, and later AgenticROS and Corebrum Mesh, are tiles in that grid. Quickshell is not in Ubuntu 24.04 or 26.04, so the session uses Waybar, Fuzzel, and `corebrum-grid`. Ubuntu 24.04 installs Hyprland from a pinned personal archive. Ubuntu 26.04 installs the Hyprland package from the Ubuntu archive. ROS 2 is Jazzy on 24.04 and Lyrical Luth on 26.04.

Original Corebrum code in this repository is under the MIT license in `LICENSE`. Third-party components keep their own licenses. The MIT choice is subject to license review.

## Current status

Phase 0 and Phase 1 are in the tree. The operator reported a successful base install, validation, and reboot on Ubuntu Server 24.04.

Phase 4 installed the `corebrum` command on this machine. Phase 4 is not accepted until the fresh Ubuntu VM procedure in `docs/installation/cli.md`. Phase 5 installed ROS 2 Jazzy and one Zenoh router on this machine. A topic, a service, an action, and a router restart passed, and `corebrum doctor` passed. Phase 5 is not accepted until a second machine exchanges messages. See `docs/installation/ros.md`.

## Preview the base install

On Ubuntu 24.04 or 26.04 x86-64:

```bash
./scripts/install.sh --profile base --dry-run
```

`--dry-run` prints the intended actions. It does not install packages, enable services, or write `/etc` or `/var`.

Apply it only on a machine you intend to turn into a Corebrum base system:

```bash
sudo ./scripts/install.sh --profile base
sudo ./scripts/validate/base.sh
```

OpenSSH is opt-in:

```bash
sudo ./scripts/install.sh --profile base --enable-ssh
```

## Preview the desktop install

```bash
./scripts/install.sh --profile desktop --dry-run
```

`--dry-run` prints the desktop actions and the Hyprland source it will use. It does not install packages or write configuration. A real install is `sudo ./scripts/install.sh --profile desktop`. The steps are in `docs/installation/desktop.md`.

## Checks

```bash
make check
```

`make check` runs ShellCheck, unit tests, and dry-runs of the base and desktop profiles. Development requirements are in `docs/development/requirements.md`.
