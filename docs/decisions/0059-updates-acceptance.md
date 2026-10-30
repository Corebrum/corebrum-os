# 0059. Phase 13 updates stay on the Super+Space menu

Date: 2026-10-26
Status: Accepted

## Context

The original phase asks for a signed Corebrum APT repository, release channels, and package rollback. The living plan already treats Phase 13 as the Updates menu. See `docs/decisions/0045-software-updates.md` and `docs/decisions/0048-cli-catch-up.md`.

## Decision

- Super+Space Updates is the update system. The rows are Ubuntu, Corebrum, ROS 2, Zenoh, Corebrum Synapse, and AI Agents. All runs those six steps in that order and stops when one fails. It does not reboot.
- `corebrum update status` lists those rows and does not run apt or git. `corebrum update system`, `corebrum update desktop`, `corebrum update robotics`, and `corebrum update agents` are refused, so a script cannot upgrade from the CLI.
- The AI Agents row reruns publisher installers only for CLIs already on `PATH`. The ROS 2 row upgrades installed `ros-<distro>-*` packages, including `rmw-zenoh-cpp`. Those two rows stay separate.
- There is no signed Corebrum repository, no Stable, Beta, or Edge channel, and no package rollback. A dirty git checkout stops the Corebrum and Corebrum Synapse rows. The weekly login note points at the menu and does not upgrade.

## Consequences

Choosing a row is what changes a running machine. A signed repository remains out of this phase.
