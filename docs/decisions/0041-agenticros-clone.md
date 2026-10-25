# 0041. AgenticROS is cloned when the checkout is missing

Date: 2026-10-24
Status: Accepted

## Context

Super+Space installs AgenticROS by building a checkout beside this repository, compiling `rclnodejs` against the installed ROS distro, and running `agenticros init --yes`. That path was written for a development machine that already had `https://github.com/agenticros/agenticros` cloned next to Corebrum OS. On 2026-10-24 a new Ubuntu Server 26.04 install, with ROS 2 and RealSense already installed, stopped with `AgenticROS clone not found at /home/corebrum/agenticros`.

The same day `git ls-remote https://github.com/agenticros/agenticros.git HEAD` resolved `refs/heads/main`. The npm package `agenticros` also exists. Its published installer copies a snapshot and builds `rclnodejs` with the package's own node-gyp. Decision 0026 records that this node-gyp does not finish on the desktop Node for Lyrical, which is why the menu compiles that addon after `pnpm install --ignore-scripts`.

## Decision

- When the sibling directory (or `COREBRUM_AGENTICROS_ROOT`) has `pnpm-workspace.yaml`, the installer builds that checkout and does not fetch it again.
- When that path is missing, the installer runs `git clone --depth 1 https://github.com/agenticros/agenticros.git` into it. `git` comes from the base profile. If the command is missing, this step installs the Ubuntu `git` package.
- A path that already exists without `pnpm-workspace.yaml` is left unchanged and the install stops.
- The build, the `rclnodejs` compile, `/usr/local/bin/agenticros`, and `agenticros init --yes` stay as described in decision 0026. The desktop profile still does not preinstall AgenticROS.

## Consequences

A new machine that cloned only Corebrum OS can install AgenticROS from Super+Space. A later choice of the same menu entry does not run `git pull`. Replacing the checkout means removing that directory first. The clone follows the default branch at the moment it is created.
