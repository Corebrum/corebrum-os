# 0042. First login walks through ROS, RealSense, AgenticROS, and AI agents

Date: 2026-10-24
Status: Accepted

## Context

A new Ubuntu Server 26.04 desktop install reboots into Hyprland with ROS 2, RealSense, AgenticROS, and the AI agent CLIs still uninstalled. Super+Space lists each one separately. On 2026-10-24 RealSense was chosen first. `realsense-install.sh` stops when `/etc/apt/sources.list.d/ros2.sources` is missing and tells the operator to install ROS 2 first. AgenticROS has the same requirement. The agent CLIs do not.

## Decision

- The first graphical login runs `corebrum-setup login`. It opens the wizard in a terminal when `${XDG_STATE_HOME:-~/.local/state}/corebrum/setup-done` is absent and any step is not installed. The desktop profile does not write that file. When every step is already installed, login writes the marker and does not open the wizard. See `docs/decisions/0046-setup-wizard-installed.md`.
- The wizard has four steps, in order: ROS 2 (`sudo corebrum install ros`), RealSense (`sudo /usr/local/lib/corebrum/realsense-install.sh`), AgenticROS (the existing build and `agenticros init --yes`), then the AI agent list from `/etc/corebrum/agents.conf`. The agent step can install more than one CLI before Skip.
- Every step accepts Skip and Exit. Exit and a finished wizard write the marker. A later login does not open the wizard. `corebrum-setup again` opens it anyway.
- When ROS 2 is not installed, RealSense and AgenticROS offer to install ROS 2 and do not start their own installers. A step that is already installed is announced and the wizard moves on.
- The wizard does not write `~/.config`. Uninstall removes `/usr/local/bin/corebrum-setup` and leaves the marker in the home directory.

## Consequences

A machine that already installed the desktop before this wizard exists will see it once on the next login, until the operator finishes it or exits, unless ROS 2, RealSense, AgenticROS, and every AI agent are already installed. In that case login writes the marker and stays closed. Super+Space remains the way to install or open any one of these later.
