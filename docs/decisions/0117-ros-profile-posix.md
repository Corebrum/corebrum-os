# 0117. ROS profile.d script is POSIX for dash

Date: 2026-11-02
Status: Accepted

## Context

Ubuntu `/etc/profile` sources `/etc/profile.d/*.sh` with `/bin/sh`, which is dash. The greeter and early session path hit that before the wallpaper. `config/ros/profile.sh` used bash `[[` and `source`, so boot printed `/bin/sh: … [[: not found` twice. The node profile already used POSIX tests and gated nvm on `BASH_VERSION`.

## Decision

- `/etc/profile.d/corebrum-ros.sh` uses POSIX `[` and `.`.
- It sources `ros-env.sh` and the ROS `setup.bash` only when `BASH_VERSION` is set.
- RMW and `ROS_DOMAIN_ID` still export under dash.

## Consequences

Dash login no longer warns. Bash login shells, `corebrum-session`, and `corebrum-terminal` still load the ROS environment.
