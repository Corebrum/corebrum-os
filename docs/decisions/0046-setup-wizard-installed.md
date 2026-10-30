# 0046. An installed machine does not open the setup wizard

Date: 2026-10-25
Status: Accepted

## Context

The first graphical login opens `corebrum-setup` when `${XDG_STATE_HOME:-~/.local/state}/corebrum/setup-done` is absent. On 2026-10-25 a reboot opened that wizard on a machine where ROS 2, RealSense, Corebrum Synapse, and every AI agent CLI were already installed. The marker was absent because those pieces had been installed from Super+Space, so the session treated the login as a first run.

## Decision

- `exec-once` runs `corebrum-setup login`. The desktop profile still does not write the marker.
- Login writes the marker and does not open a terminal when ROS 2, RealSense, Corebrum Synapse, and every agent in `/etc/corebrum/agents.conf` are already installed. The same check applies when `corebrum-setup` is started with no arguments.
- A missing piece still opens the wizard. Exit, and a wizard that finishes, write the marker. `corebrum-setup again` opens the wizard anyway.
- When every AI agent is already installed, that step says so and the wizard finishes.

## Consequences

A reboot of a machine that already has the whole set stays on the desktop. Adding an agent to the catalog later opens the wizard once on a machine that has no marker yet. Super+Space remains the way to install or open any one piece after that.
