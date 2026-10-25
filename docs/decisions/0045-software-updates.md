# 0045. Software updates stay user-started

Date: 2026-10-25
Status: Accepted

## Context

A Corebrum desktop installs Ubuntu packages, a git checkout, ROS 2, a pinned Zenoh client, AgenticROS, and optional AI agent CLIs. Each one updates on its own command. An unattended weekly `apt upgrade` can restart Hyprland, ROS, and the Zenoh router while a robot is in use.

## Decision

- Super+Space lists Updates. The idle list is one row. The submenu is Ubuntu, Corebrum, ROS 2, Zenoh, AgenticROS, AI Agents, and All.
- All runs those six steps in that order in one terminal. A failed step stops the rest. The terminal says when `/var/run/reboot-required` exists. It does not reboot.
- Ubuntu runs `apt-get update` and `apt-get upgrade` and stays on the current release.
- Corebrum resolves the checkout from `/usr/local/bin/corebrum`, fast-forwards it as the logged-in user, then runs `sudo corebrum install desktop`. A dirty checkout or a pull that is not fast-forward stops the step. The operator logs out so Hyprland reloads the copied config.
- ROS 2 runs `sudo corebrum install ros`, then `apt-get install --only-upgrade` for `ros-<distro>-*` packages already installed. That includes `ros-<distro>-rmw-zenoh-cpp`. The row is skipped when ROS 2 is not installed.
- Zenoh does not install Eclipse `zenohd`. The router package moves with ROS 2. This row reinstalls `eclipse-zenoh` and `zenoh-cli` at the pins in `scripts/lib/ros.sh` into `/opt/corebrum/zenoh-cli` and recopies `/usr/local/bin/zenoh`. When `zenoh-fleet` is already on `PATH`, it reinstalls `@agenticros/zenoh-fleet` at the pin in `scripts/desktop/corebrum-zenoh-fleet-menu.sh`. It does not edit the router or the fleet files in the home directory. The client reinstall is skipped when ROS 2 is not installed.
- AgenticROS reads `/etc/corebrum/agenticros.root`, fetches `origin/main` with depth 1, fast-forwards, runs `agenticros-install.sh`, and runs `agenticros init --yes`. A dirty checkout stops the step. The row is skipped when AgenticROS is not installed.
- AI Agents reruns the existing install command only for CLIs already on `PATH`, then `agenticros mcp setup` for each one when AgenticROS is configured.
- On login, `exec-once` calls `corebrum-updates-menu remind`. When `${XDG_STATE_HOME:-~/.local/state}/corebrum/updates-reminded` is older than 7 days, it sends a notification and refreshes the stamp. It does not run apt or git, write `~/.config`, or add a cron job.

## Consequences

Choosing a row is what upgrades the machine. The weekly notification only points at the menu. A checkout with local changes has to be cleaned up before Corebrum or AgenticROS will fast-forward.
