# Corebrum OS

The operating environment for Physical AI. Corebrum OS runs on Ubuntu Server 24.04 LTS (x86-64). It is not a new kernel or a new package manager.

The desktop, added in a later phase, follows [Omarchy](https://github.com/omacom/omarchy): a keyboard-first Hyprland session and a Quickshell app grid. Robotics tools such as ROS 2 (Zenoh RMW), RViz, and Gazebo, and later AgenticROS and Corebrum Mesh, are tiles in that grid. This repository currently contains the base installer only.

Original Corebrum code in this repository is under the MIT license in `LICENSE`. Third-party components keep their own licenses. The MIT choice is subject to license review.

## Current status

Phase 0 and Phase 1 are implemented in this tree:

- Repository layout, agent instructions, and architecture decisions
- Idempotent Ubuntu Server 24.04 base installer with `--dry-run`
- ShellCheck, unit tests, a dry-run smoke test, and GitHub Actions

A fresh virtual machine install, reboot, and second install are still required before Phase 1 is accepted. See `docs/installation/ubuntu-server.md`.

## Preview the base install

On Ubuntu 24.04 x86-64:

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

## Checks

```bash
make check
```

`make check` runs ShellCheck, unit tests, and the base dry-run. Development requirements are in `docs/development/requirements.md`.
