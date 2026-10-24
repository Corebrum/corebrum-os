# Corebrum OS

The operating environment for Physical AI. Corebrum OS runs on Ubuntu Server 24.04 or 26.04 LTS (x86-64). It is not a new kernel or a new package manager.

The desktop design was inspired by Omarchy: a keyboard-first Hyprland session and an app grid. Robotics tools such as ROS 2 (Zenoh RMW), RViz, Gazebo, and AgenticROS are tiles in that grid. Quickshell is not in Ubuntu 24.04 or 26.04, so the session uses Waybar, Fuzzel, and `corebrum-grid`. Ubuntu 24.04 installs Hyprland from a pinned personal archive. Ubuntu 26.04 installs the Hyprland package from the Ubuntu archive. ROS 2 is Jazzy on 24.04 and Lyrical Luth on 26.04.

AI Agents are built into the OS. [AgenticROS](https://agenticros.com) gives those agents full control over their own ROS-powered bodies, including eyes, wheels, legs, arms, propellers, and more.

Original Corebrum code in this repository is under the MIT license in `LICENSE`. Third-party components keep their own licenses. The MIT choice is subject to license review.

## Current status

Phase 0 and Phase 1 are in the tree. The operator reported a successful base install, validation, and reboot on Ubuntu Server 24.04.

Phase 4 installed the `corebrum` command on this machine. Phase 4 is not accepted until the fresh Ubuntu VM procedure in `docs/installation/cli.md`. Phase 5 installed ROS 2 Jazzy and one Zenoh router on this machine. A topic, a service, an action, and a router restart passed, and `corebrum doctor` passed. Phase 5 is not accepted until a second machine exchanges messages. See `docs/installation/ros.md`.

## First console

A fresh server does not have this repository yet. Install `git`, then clone it:

```bash
sudo apt update
sudo apt install -y git ca-certificates
git clone https://github.com/Corebrum/corebrum-os.git
cd corebrum-os
```

The Cursor agent install, `agent login`, and a `PATH` line in `~/.bashrc` stay on your account. The installer does not write a home directory and does not install Cursor. The editor in the base profile is `nano`.

### Headless server

The base profile is the Ubuntu Server foundation. It runs `apt-get update` and installs `curl`, `ca-certificates`, `tmux`, and `nano`. `--enable-ssh` installs OpenSSH and enables the `ssh` service. `hostname -I` prints an address you can connect to.

```bash
sudo ./scripts/install.sh --profile base --enable-ssh
hostname -I
```

### Desktop

The desktop profile is the Hyprland machine: the session, the greetd login, the logo, and workstation services. Its first step installs the base profile. Add `--enable-ssh` on the same command when the machine should accept SSH.

```bash
sudo ./scripts/install.sh --profile desktop --enable-ssh
```

After the `corebrum` command is on `PATH`, the same install is `sudo corebrum install desktop`. Reboot when the installer finishes. The login screen is on VT 7 (`Ctrl+Alt+F7`). VT 1 (`Ctrl+Alt+F1`) stays a text console. The steps are in `docs/installation/desktop.md`.

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

`--dry-run` prints the desktop actions and the Hyprland source it will use. It does not install packages or write configuration. The install command is in [Desktop](#desktop) above.

## Checks

```bash
make check
```

`make check` runs ShellCheck, unit tests, and dry-runs of the base and desktop profiles. Development requirements are in `docs/development/requirements.md`.
