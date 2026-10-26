# Corebrum OS

The operating environment for Physical AI. Corebrum OS runs on Ubuntu Server 24.04 or 26.04 LTS (x86-64). It is not a new kernel or a new package manager.

The desktop design was inspired by Omarchy: a keyboard-first Hyprland session and an app grid. Robotics tools such as ROS 2 (Zenoh RMW), RViz, Gazebo, and AgenticROS are tiles in that grid. Quickshell is not in Ubuntu 24.04 or 26.04, so the session uses Waybar, Fuzzel, and `corebrum-grid`. Ubuntu 24.04 installs Hyprland from a pinned personal archive. Ubuntu 26.04 installs the Hyprland package from the Ubuntu archive. ROS 2 is Jazzy on 24.04 and Lyrical Luth on 26.04.

AI Agents are built into the OS. [AgenticROS](https://agenticros.com) gives those agents full control over their own ROS-powered bodies, including eyes, wheels, legs, arms, propellers, and more.

Original Corebrum code in this repository is under the MIT license in `LICENSE`. Third-party components keep their own licenses. The MIT choice is subject to license review.

## Demo

[![Meet Corebrum, the Physical AI Operating System](docs/images/demo.jpg)](https://www.youtube.com/watch?v=a010iQF9h7g)

[Meet Corebrum](https://www.youtube.com/watch?v=a010iQF9h7g) walks through the desktop with ROS 2, Gazebo, RealSense, and the built-in AI agents.

## Current status

Phase 0 and Phase 1 are in the tree. The operator reported a successful base install, validation, and reboot on Ubuntu Server 24.04.

Phase 4 installed the `corebrum` command on this machine. Phase 4 is not accepted until the fresh Ubuntu VM procedure in `docs/installation/cli.md`. Phase 5 installed ROS 2 Jazzy and one Zenoh router on this machine. A topic, a service, an action, and a router restart passed, and `corebrum doctor` passed. Phase 5 is not accepted until a second machine exchanges messages. See `docs/installation/ros.md`.

## Install

A fresh server does not have this repository yet:

```bash
sudo apt update
sudo apt install -y git ca-certificates
git clone https://github.com/Corebrum/corebrum-os.git
cd corebrum-os
sudo ./scripts/install.sh --profile desktop
```

`--profile desktop` installs the base profile first, then the Hyprland session and workstation services. You do not need to run `--profile base` before it.

After the `corebrum` command exists, the same install is `sudo corebrum install desktop`.

Reboot when that finishes. The login screen is on VT 7 (`Ctrl+Alt+F7`). VT 1 (`Ctrl+Alt+F1`) stays a text console. The steps are in `docs/installation/desktop.md`.

Add `--enable-ssh` on that same command if you want OpenSSH enabled during the install:

```bash
sudo ./scripts/install.sh --profile desktop --enable-ssh
```

The Cursor agent install, `agent login`, and a `PATH` line in `~/.bashrc` stay on your account. The installer does not write a home directory and does not install Cursor. The editor in the base profile is `nano`.

### Updates

Super+Space **Updates** upgrades Ubuntu, this checkout, ROS 2, Zenoh, AgenticROS, and the AI agents already installed. **All** runs those six steps in order. A login reminder once a week points at that menu and does not apply upgrades. The row-by-row commands are in `docs/installation/desktop.md` and `docs/decisions/0045-software-updates.md`.

### Headless server

The base profile is the Ubuntu Server foundation. It runs `apt-get update` and installs `curl`, `ca-certificates`, `tmux`, and `nano`. `--enable-ssh` installs OpenSSH and enables the `ssh` service. `hostname -I` prints an address you can connect to.

```bash
sudo ./scripts/install.sh --profile base --enable-ssh
hostname -I
```

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

`--dry-run` prints the desktop actions and the Hyprland source it will use. It does not install packages or write configuration. The install command is in [Install](#install) above.

## Checks

```bash
make check
```

`make check` runs ShellCheck, unit tests, and dry-runs of the base and desktop profiles. Development requirements are in `docs/development/requirements.md`.
